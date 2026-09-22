import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Tools the server model can call mid-reply. The framework runs `call` when
/// the model asks; the app performs the request and hands the text back.
struct CoachFoodLookupTool: Tool {
    let name = "lookupFood"
    let description = "Nutrition facts for a food or branded product from USDA FoodData Central and Open Food Facts: calories, protein, fiber, sugars, added sugars, fat, and minerals (sodium, potassium, calcium, iron, magnesium) per serving when listed. Call once for each food you are about to give numbers for, even one you think you know; when nothing comes back, say so rather than estimating the label. Not needed for foods you are only recommending."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "The food or product, with brand when known, e.g. 'Clif oatmeal raisin walnut bar' or 'black beans cooked'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let startedAt = Date()
        let result = await CoachFoodService.lookupText(query: arguments.query)
        let outcome: String
        if result.hasPrefix("Matches for") {
            outcome = "match"
        } else if result.hasPrefix("Food lookup unavailable") {
            outcome = "unavailable"
        } else {
            outcome = "no match"
        }
        await context.log(
            name,
            detail: arguments.query,
            outcome: outcome,
            startedAt: startedAt
        )
        return result
    }
}

struct CoachEvidenceSearchTool: Tool {
    let name = "searchEvidence"
    let description = "PubMed search returning real studies with title, journal, year, PMID, and abstract. Call before attributing anything to research, the literature, or a study, and cite only what comes back. Your own expertise needs no citation; a citation needs this."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "A focused topic, e.g. 'dietary fiber satiety breakfast' or 'implementation intentions habit formation'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let startedAt = Date()
        let result = await CoachEvidenceService.searchText(query: arguments.query)
        let outcome: String
        if result.hasPrefix("PubMed results") {
            outcome = "match"
        } else if result.hasPrefix("PubMed matched") {
            outcome = "abstract unavailable"
        } else {
            outcome = "no match"
        }
        await context.log(
            name,
            detail: arguments.query,
            outcome: outcome,
            startedAt: startedAt
        )
        return result
    }
}

struct CoachCalculatorTool: Tool {
    let name = "calculate"
    let description = "Exact arithmetic. Use for any total, difference, percentage, or per-kilogram figure instead of computing in prose, e.g. '250 + 230 + 100' or '20 / 50 * 100' or '1.4 * 84'."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "An arithmetic expression using numbers, + - * / ^ ( ) and %. Unit words are ignored.")
        var expression: String
    }

    func call(arguments: Arguments) async throws -> String {
        let result = CoachCalculator.answer(arguments.expression)
        await context.log(
            name,
            detail: arguments.expression,
            outcome: result.hasPrefix("Could not evaluate") ? "error" : "success"
        )
        return result
    }
}
#endif
