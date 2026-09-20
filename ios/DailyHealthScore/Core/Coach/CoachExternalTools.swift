import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Tools the server model can call mid-reply. The framework runs `call` when
/// the model asks; the app performs the request and hands the text back.
@available(iOS 26.0, *)
struct CoachFoodLookupTool: Tool {
    let name = "lookupFood"
    let description = "Nutrition facts for a food or branded product from USDA FoodData Central and Open Food Facts: calories, protein, fiber, sugars, added sugars per serving. Call once per food or product the person named before estimating anything."

    @Generable
    struct Arguments {
        @Guide(description: "The food or product, with brand when known, e.g. 'Clif oatmeal raisin walnut bar' or 'black beans cooked'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        await CoachFoodService.lookupText(query: arguments.query)
    }
}

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
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

@available(iOS 26.0, *)
struct CoachBodyTrendTool: Tool {
    let name = "lookupWeightTrend"
    let description = "The person's weight trend and BMI as shared from Apple Health: seven-day level, change over four and twelve weeks, BMI as a screening number. Use when weight, protein needs, or energy needs come up. Never for praise or judgment."
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
