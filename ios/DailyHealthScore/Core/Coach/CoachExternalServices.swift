import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Public food databases the Coach can consult. Requests carry a food name and
/// nothing about the person. USDA first (label values, branded products), Open
/// Food Facts when USDA has nothing.
enum CoachFoodService {
    static let requestTimeout: TimeInterval = 8
    static let userAgent = "DailyHealthScore/1.7 (iOS; lifestyle coach food lookup)"

    static func lookupText(query: String, session: URLSession = .shared) async -> String {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else { return "No food named. Ask what they ate, or estimate and label it approximate." }
        let result = await lookup(query: cleaned, session: session)
        return formatted(result.facts, query: cleaned, failures: result.failures)
    }

    struct LookupResult: Equatable {
        var facts: [CoachFoodFact]
        /// Transport-level trouble, per source, so "approximate" can say why.
        var failures: [String]
    }

    static func lookup(query: String, session: URLSession = .shared) async -> LookupResult {
        var failures: [String] = []
        switch await fetch(usdaSearchURL(query: query), session: session) {
        case .success(let data):
            let facts = USDAFoodParser.facts(fromSearchJSON: data, limit: 3)
            if !facts.isEmpty { return LookupResult(facts: facts, failures: []) }
        case .failure(let reason):
            failures.append("USDA: \(reason.description)")
        }
        switch await fetch(openFoodFactsSearchURL(query: query), session: session) {
        case .success(let data):
            return LookupResult(facts: OpenFoodFactsParser.facts(fromSearchJSON: data, limit: 3), failures: failures)
        case .failure(let reason):
            failures.append("Open Food Facts: \(reason.description)")
        }
        return LookupResult(facts: [], failures: failures)
    }

    static func formatted(_ facts: [CoachFoodFact], query: String, failures: [String] = []) -> String {
        guard !facts.isEmpty else {
            if !failures.isEmpty {
                return "Food lookup unavailable for \"\(query)\" (\(failures.joined(separator: "; "))). Estimate typical values, label them approximate, state the serving you assumed, and say the database did not respond."
            }
            return "No database match for \"\(query)\". Estimate typical values, label them approximate, and state the serving you assumed."
        }
        let lines = facts.enumerated().map { index, fact in "\(index + 1). \(fact.line)" }
        return """
        Matches for "\(query)" (label values; pick the one that fits what they described and say which):
        \(lines.joined(separator: "\n"))
        Use the calculator for totals. Added sugar is listed only when the label reports it.
        """
    }

    static func usdaSearchURL(query: String, key: String = CoachSecrets.usdaKey()) -> URL? {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "5"),
            URLQueryItem(name: "dataType", value: "Branded,Foundation,SR Legacy")
        ]
        return components?.url
    }

    static func openFoodFactsSearchURL(query: String) -> URL? {
        var components = URLComponents(string: "https://world.openfoodfacts.org/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "search_simple", value: "1"),
            URLQueryItem(name: "action", value: "process"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: "5"),
            URLQueryItem(name: "fields", value: "product_name,brands,nutriments,serving_size")
        ]
        return components?.url
    }

    enum FetchFailure: Error, Equatable {
        case badURL
        case http(Int)
        case transport(String)

        var description: String {
            switch self {
            case .badURL: return "bad URL"
            case .http(let code): return code == 429 ? "HTTP 429 rate limited" : "HTTP \(code)"
            case .transport(let message): return message
            }
        }
    }

    static func fetch(_ url: URL?, session: URLSession) async -> Result<Data, FetchFailure> {
        guard let url else { return .failure(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failure(.transport("no HTTP response")) }
            guard (200..<300).contains(http.statusCode) else { return .failure(.http(http.statusCode)) }
            return .success(data)
        } catch {
            return .failure(.transport(error.localizedDescription))
        }
    }
}

/// PubMed, so "the evidence shows" can be followed by a citation that exists.
/// Queries carry a topic and nothing about the person.
enum CoachEvidenceService {
    static let requestTimeout: TimeInterval = 8
    static let baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"

    static func searchText(query: String, limit: Int = 3, session: URLSession = .shared) async -> String {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 3 else { return "No topic given." }
        // Reviews and trials first; fall back to anything when the filter is too tight.
        let filtered = "(\(cleaned)) AND (review[pt] OR meta-analysis[pt] OR randomized controlled trial[pt])"
        var ids = await search(term: filtered, limit: limit, session: session)
        if ids.isEmpty {
            ids = await search(term: cleaned, limit: limit, session: session)
        }
        guard !ids.isEmpty else {
            return "PubMed returned nothing for \"\(cleaned)\". Answer from general knowledge and say no source was found."
        }
        let abstracts = await fetchAbstracts(ids: ids, session: session)
        guard !abstracts.isEmpty else {
            return "PubMed matched PMIDs \(ids.joined(separator: ", ")) but the abstracts did not load. Cite by PMID only if you must."
        }
        return """
        PubMed results for "\(cleaned)" (cite title, journal, year, PMID; quote findings, never invent numbers):
        \(abstracts.joined(separator: "\n\n"))
        """
    }

    static func search(term: String, limit: Int, session: URLSession) async -> [String] {
        var components = URLComponents(string: "\(baseURL)/esearch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "retmax", value: String(limit)),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "retmode", value: "json"),
            URLQueryItem(name: "tool", value: "DailyHealthScore")
        ]
        guard case .success(let data) = await CoachFoodService.fetch(components?.url, session: session) else { return [] }
        return PubMedParser.ids(fromSearchJSON: data)
    }

    static func fetchAbstracts(ids: [String], session: URLSession) async -> [String] {
        var components = URLComponents(string: "\(baseURL)/efetch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "rettype", value: "abstract"),
            URLQueryItem(name: "retmode", value: "text"),
            URLQueryItem(name: "tool", value: "DailyHealthScore")
        ]
        guard case .success(let data) = await CoachFoodService.fetch(components?.url, session: session),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return PubMedParser.records(fromAbstractText: text)
    }
}

enum PubMedParser {
    static func ids(fromSearchJSON data: Data) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["esearchresult"] as? [String: Any],
              let ids = result["idlist"] as? [String] else { return [] }
        return ids
    }

    /// efetch's plain-text abstracts separate records with two blank lines.
    /// Each record is trimmed to a readable size for the prompt.
    static func records(fromAbstractText text: String, maxCharacters: Int = 1_100) -> [String] {
        text.components(separatedBy: "\n\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 40 }
            .prefix(3)
            .map { record in
                let collapsed = record
                    .replacingOccurrences(of: "\n\n", with: "\n")
                    .replacingOccurrences(of: "  ", with: " ")
                guard collapsed.count > maxCharacters else { return collapsed }
                return String(collapsed.prefix(maxCharacters)) + "…"
            }
    }
}
