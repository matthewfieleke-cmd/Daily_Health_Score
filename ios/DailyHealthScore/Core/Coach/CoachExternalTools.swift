import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Tools the server model can call mid-reply. The framework runs `call` when
/// the model asks; the app performs the request and hands the text back.
struct CoachFoodLookupTool: Tool {
    let name = "lookupFood"
    let description = CoachToolCopy.lookupFood
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
    let description = CoachToolCopy.searchEvidence
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
    let description = CoachToolCopy.calculate
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
