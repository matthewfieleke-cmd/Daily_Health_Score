import Foundation

/// The subset of Markdown the Coach is allowed to write: paragraphs, **bold**,
/// _italics_, and short bullet or numbered lists. Headers are folded into bold
/// paragraphs, tables and code fences are shown as plain text.
enum CoachMarkdownBlock: Equatable, Sendable {
    case paragraph(String)
    case bullets([String])
    case numbered([String])
}

enum CoachMarkdown {
    static func blocks(from text: String) -> [CoachMarkdownBlock] {
        var blocks: [CoachMarkdownBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []

        func flushParagraph() {
            let joined = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            if !joined.isEmpty { blocks.append(.paragraph(joined)) }
            paragraph = []
        }
        func flushLists() {
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flushParagraph()
                flushLists()
                continue
            }
            if let item = bulletItem(line) {
                flushParagraph()
                if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
                bullets.append(item)
                continue
            }
            if let item = numberedItem(line) {
                flushParagraph()
                if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
                numbered.append(item)
                continue
            }
            flushLists()
            if let heading = headingText(line) {
                flushParagraph()
                blocks.append(.paragraph("**\(heading)**"))
                continue
            }
            paragraph.append(line.replacingOccurrences(of: "```", with: ""))
        }
        flushParagraph()
        flushLists()
        return blocks
    }

    /// Text with markers removed, for chat-row previews and accessibility.
    static func plainText(_ text: String) -> String {
        var lines: [String] = []
        for rawLine in text.components(separatedBy: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if let item = bulletItem(line) {
                line = item
            } else if let item = numberedItem(line) {
                line = item
            } else if let heading = headingText(line) {
                line = heading
            }
            lines.append(line)
        }
        return lines
            .joined(separator: "\n")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func bulletItem(_ line: String) -> String? {
        for marker in ["- ", "• ", "* ", "– "] where line.hasPrefix(marker) {
            let item = line.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
            return item.isEmpty ? nil : item
        }
        return nil
    }

    static func numberedItem(_ line: String) -> String? {
        var digits = ""
        var rest = Substring(line)
        while let first = rest.first, first.isNumber, digits.count < 3 {
            digits.append(first)
            rest = rest.dropFirst()
        }
        guard !digits.isEmpty, let punct = rest.first, punct == "." || punct == ")" else { return nil }
        let item = rest.dropFirst().trimmingCharacters(in: .whitespaces)
        return item.isEmpty ? nil : item
    }

    static func headingText(_ line: String) -> String? {
        guard line.hasPrefix("#") else { return nil }
        let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
