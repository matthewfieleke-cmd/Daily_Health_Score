import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Tools the server model can call mid-reply. The framework runs `call` when
/// the model asks; the app performs the request and hands the text back.
struct CoachFoodLookupTool: Tool {
    let name = "lookupFood"
    let description = "Nutrition facts for a food or branded product from USDA FoodData Central and Open Food Facts: calories, protein, fiber, sugars, added sugars, fat, and minerals per serving when listed. Call once for each food you are about to give numbers for, even one you think you know. The result says exact, candidates, or none. Candidate items do not belong in an exact total; ask for the package label when exact numbers matter. Not needed for foods you are only recommending."
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
        if result.hasPrefix("Exact database match") {
            outcome = "exact match"
        } else if result.hasPrefix("Candidate database matches") {
            outcome = "candidates"
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
    let description = "PubMed records with title, journal, year, PMID, and abstract kept together. Call when the person asks for evidence or a citation, or when a current, unfamiliar, or precise claim needs verification. Ordinary explanations should use your own expertise. A keyword match is evidence only when the study actually answers the question; cite only what comes back."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "A focused topic, e.g. 'dietary fiber satiety breakfast' or 'implementation intentions habit formation'.")
        var query: String
    }

    func call(arguments: Arguments) async throws -> String {
        let startedAt = Date()
        let permission = await context.beginEvidenceSearch(arguments.query)
        switch permission {
        case .duplicate:
            await context.log(
                name,
                detail: arguments.query,
                outcome: "deduplicated"
            )
            return "No new PubMed search: this topic was already searched this turn."
        case .turnLimit:
            await context.log(
                name,
                detail: arguments.query,
                outcome: "turn limit"
            )
            return "No new PubMed search: two distinct evidence queries already ran this turn."
        case .search:
            break
        }
        let result = await CoachEvidenceService.searchText(query: arguments.query)
        let outcome: String
        if result.hasPrefix("PubMed results") {
            outcome = "match"
        } else if result.hasPrefix("PubMed records unavailable") {
            outcome = "unavailable"
        } else {
            outcome = "no match"
        }
        if case .search(let index) = permission {
            await context.finishEvidenceSearch(index: index, matched: outcome == "match")
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
    let description = "Exact arithmetic and weight conversion. Use for any total, difference, percentage, unit conversion, or per-kilogram figure instead of computing in prose, e.g. '250 + 230 + 100', '20 / 50 * 100', or '268.7 lb to kg'. A g/kg formula must use kilograms, never pounds."
    let context: CoachLiveContext

    @Generable
    struct Arguments {
        @Guide(description: "An arithmetic expression using numbers, + - * / ^ ( ) and %, or a weight conversion such as 268.7 lb to kg.")
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
