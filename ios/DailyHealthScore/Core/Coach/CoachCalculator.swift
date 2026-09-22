import Foundation

/// Exact arithmetic for the Coach. Language models add badly; this does not.
/// Supports + - * / ^, parentheses, decimals, percentages ("15% of 200",
/// "20/50 * 100"), and unit words that are ignored ("250 kcal + 230 kcal").
enum CoachCalculator {
    enum CalculationError: Error, Equatable {
        case empty
        case unexpected(String)
        case divisionByZero
    }

    static func evaluate(_ expression: String) throws -> Double {
        var parser = Parser(tokens: try tokenize(expression))
        guard !parser.tokens.isEmpty else { throw CalculationError.empty }
        let value = try parser.parseExpression()
        guard parser.isAtEnd else { throw CalculationError.unexpected(parser.peekDescription) }
        guard value.isFinite else { throw CalculationError.divisionByZero }
        return value
    }

    /// "12.5" or "13" — no trailing zeros, at most two decimals.
    static func format(_ value: Double) -> String {
        if value.rounded() == value, abs(value) < 1e12 {
            return String(Int(value))
        }
        let text = String(format: "%.2f", value)
        return text.replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
    }

    /// The tool's reply: the expression restated with its result.
    static func answer(_ expression: String) -> String {
        if let conversion = weightConversion(expression) {
            return "\(format(conversion.input)) \(conversion.from) = \(format(conversion.output)) \(conversion.to)"
        }
        do {
            let value = try evaluate(expression)
            return "\(expression.trimmingCharacters(in: .whitespacesAndNewlines)) = \(format(value))"
        } catch {
            return "Could not evaluate \"\(expression)\". Use numbers with + - * / ( ) and %; words for units are ignored."
        }
    }

    private static func weightConversion(
        _ expression: String
    ) -> (input: Double, from: String, output: Double, to: String)? {
        let normalized = expression.lowercased()
            .replacingOccurrences(of: "pounds", with: "lb")
            .replacingOccurrences(of: "pound", with: "lb")
            .replacingOccurrences(of: "lbs", with: "lb")
            .replacingOccurrences(of: "kilograms", with: "kg")
            .replacingOccurrences(of: "kilogram", with: "kg")
        let pattern = #"(-?[0-9]+(?:\.[0-9]+)?)\s*(lb|kg)\s*(?:to|in)\s*(lb|kg)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: normalized,
                range: NSRange(normalized.startIndex..., in: normalized)
              ),
              let valueRange = Range(match.range(at: 1), in: normalized),
              let fromRange = Range(match.range(at: 2), in: normalized),
              let toRange = Range(match.range(at: 3), in: normalized),
              let input = Double(normalized[valueRange]) else {
            return nil
        }
        let from = String(normalized[fromRange])
        let to = String(normalized[toRange])
        guard from != to else {
            return (input, from, input, to)
        }
        let output = from == "lb" ? input / 2.20462262 : input * 2.20462262
        return (input, from, output, to)
    }

    // MARK: - Tokenizer

    enum Token: Equatable {
        case number(Double)
        case plus, minus, star, slash, caret, percent
        case open, close
        case of
    }

    static func tokenize(_ expression: String) throws -> [Token] {
        var tokens: [Token] = []
        let scalars = Array(expression.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: ",", with: ""))
        var index = 0
        while index < scalars.count {
            let character = scalars[index]
            if character.isWhitespace {
                index += 1
            } else if character.isNumber || (character == "." && index + 1 < scalars.count && scalars[index + 1].isNumber) {
                var text = ""
                while index < scalars.count, scalars[index].isNumber || scalars[index] == "." {
                    text.append(scalars[index])
                    index += 1
                }
                guard let value = Double(text) else { throw CalculationError.unexpected(text) }
                tokens.append(.number(value))
            } else if character.isLetter {
                var word = ""
                while index < scalars.count, scalars[index].isLetter {
                    word.append(scalars[index])
                    index += 1
                }
                let lower = word.lowercased()
                if lower == "of" {
                    tokens.append(.of)
                } else if lower == "x" {
                    tokens.append(.star)
                }
                // Any other word is a unit or filler ("kcal", "grams", "plus" is not supported).
            } else {
                switch character {
                case "+": tokens.append(.plus)
                case "-": tokens.append(.minus)
                case "*": tokens.append(.star)
                case "/": tokens.append(.slash)
                case "^": tokens.append(.caret)
                case "%": tokens.append(.percent)
                case "(": tokens.append(.open)
                case ")": tokens.append(.close)
                case "=": break
                default: throw CalculationError.unexpected(String(character))
                }
                index += 1
            }
        }
        return tokens
    }

    // MARK: - Parser

    struct Parser {
        var tokens: [Token]
        var position = 0

        var isAtEnd: Bool { position >= tokens.count }
        var peekDescription: String { isAtEnd ? "end" : "\(tokens[position])" }

        init(tokens: [Token]) {
            self.tokens = tokens
        }

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while !isAtEnd {
                switch tokens[position] {
                case .plus:
                    position += 1
                    value += try parseTerm()
                case .minus:
                    position += 1
                    value -= try parseTerm()
                default:
                    return value
                }
            }
            return value
        }

        mutating func parseTerm() throws -> Double {
            var value = try parseFactor()
            while !isAtEnd {
                switch tokens[position] {
                case .star:
                    position += 1
                    value *= try parseFactor()
                case .slash:
                    position += 1
                    let divisor = try parseFactor()
                    guard divisor != 0 else { throw CalculationError.divisionByZero }
                    value /= divisor
                case .of:
                    // "15% of 200": the percent factor already became 0.15.
                    position += 1
                    value *= try parseFactor()
                default:
                    return value
                }
            }
            return value
        }

        mutating func parseFactor() throws -> Double {
            var base = try parseUnary()
            if !isAtEnd, tokens[position] == .caret {
                position += 1
                let exponent = try parseUnary()
                base = pow(base, exponent)
            }
            return base
        }

        mutating func parseUnary() throws -> Double {
            guard !isAtEnd else { throw CalculationError.unexpected("end") }
            switch tokens[position] {
            case .minus:
                position += 1
                return -(try parseUnary())
            case .plus:
                position += 1
                return try parseUnary()
            default:
                return try parsePrimary()
            }
        }

        mutating func parsePrimary() throws -> Double {
            guard !isAtEnd else { throw CalculationError.unexpected("end") }
            var value: Double
            switch tokens[position] {
            case .number(let number):
                position += 1
                value = number
            case .open:
                position += 1
                value = try parseExpression()
                guard !isAtEnd, tokens[position] == .close else { throw CalculationError.unexpected("missing )") }
                position += 1
            default:
                throw CalculationError.unexpected(peekDescription)
            }
            if !isAtEnd, tokens[position] == .percent {
                position += 1
                value /= 100
            }
            return value
        }
    }
}
