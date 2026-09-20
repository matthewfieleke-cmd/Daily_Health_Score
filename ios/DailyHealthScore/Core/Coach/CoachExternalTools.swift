import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Tools the server model can call mid-reply. The framework runs `call` when
/// the model asks; the app performs the request and hands the text back.
struct CoachFoodLookupTool: Tool {
    let name = "lookupFood"
    let description = "Nutrition facts for a food or branded product from USDA FoodData Central and Open Food Facts: calories, protein, fiber, sugars, added sugars, fat, and minerals (sodium, potassium, calcium, iron, magnesium) per serving when listed. Call once per food or product the person named or asked about; not for foods you are merely recommending."

    @Generable
    struct Arguments {
        @Guide(description: "The food or product, with brand when known, e.g. 'Clif oatmeal raisin walnut bar' or 'black beans cooked'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await CoachFoodService.lookupText(query: arguments.query)
    }
}

struct CoachEvidenceSearchTool: Tool {
    let name = "searchEvidence"
    let description = "PubMed search returning real studies with title, journal, year, PMID, and abstract. Use when a claim deserves a source; cite only what comes back."

    @Generable
    struct Arguments {
        @Guide(description: "A focused topic, e.g. 'dietary fiber satiety breakfast' or 'implementation intentions habit formation'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await CoachEvidenceService.searchText(query: arguments.query)
    }
}

struct CoachCalculatorTool: Tool {
    let name = "calculate"
    let description = "Exact arithmetic. Use for any total, difference, percentage, or per-kilogram figure instead of computing in prose, e.g. '250 + 230 + 100' or '20 / 50 * 100' or '1.4 * 84'."

    @Generable
    struct Arguments {
        @Guide(description: "An arithmetic expression using numbers, + - * / ^ ( ) and %. Unit words are ignored.")
        var expression: String
    }

    func call(arguments: Arguments) async throws -> String {
        CoachCalculator.answer(arguments.expression)
    }
}

struct CoachBodyTrendTool: Tool {
    let name = "lookupWeightTrend"
    let description = "The person's weight trend, BMI, age, and sex as shared from Apple Health: seven-day level, change over four and twelve weeks, BMI as a screening number. Use when weight, age, protein needs, or energy needs come up. Never for praise or judgment; never guess an age instead of calling this."
    let payload: String

    @Generable
    struct Arguments {
        @Guide(description: "Why the trend is needed.")
        var reason: String
    }

    func call(arguments: Arguments) async throws -> String {
        _ = arguments
        return payload
    }
}
#endif
