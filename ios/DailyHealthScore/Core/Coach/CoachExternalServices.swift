import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(FoundationXML)
import FoundationXML
#endif

/// Public food databases the Coach can consult. Requests carry a food name and
/// nothing about the person. USDA first (label values, branded products), Open
/// Food Facts when USDA has nothing.
enum CoachFoodService {
    static let requestTimeout: TimeInterval = 8
    static let userAgent = "DailyHealthScore/1.7 (iOS; lifestyle coach food lookup)"

    static func lookupText(query: String, session: URLSession = .shared) async -> String {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count >= 2 else { return "No food named. Ask which food or product they mean." }
        let result = await lookup(query: cleaned, session: session)
        return formatted(result.facts, query: cleaned, failures: result.failures)
    }

    struct LookupResult: Equatable {
        var facts: [CoachFoodFact]
        /// Transport-level trouble, per source, so an incomplete lookup says why.
        var failures: [String]
    }

    static func lookup(query: String, session: URLSession = .shared) async -> LookupResult {
        async let usda = fetch(usdaSearchURL(query: query), session: session)
        async let openFoodFacts = fetch(openFoodFactsSearchURL(query: query), session: session)
        let (usdaResult, openFoodFactsResult) = await (usda, openFoodFacts)

        var facts: [CoachFoodFact] = []
        var failures: [String] = []
        switch usdaResult {
        case .success(let data):
            facts.append(contentsOf: USDAFoodParser.facts(fromSearchJSON: data, limit: 5))
        case .failure(let reason):
            failures.append("USDA: \(reason.description)")
        }
        switch openFoodFactsResult {
        case .success(let data):
            facts.append(contentsOf: OpenFoodFactsParser.facts(fromSearchJSON: data, limit: 5))
        case .failure(let reason):
            failures.append("Open Food Facts: \(reason.description)")
        }
        return LookupResult(facts: rankedFacts(facts, query: query, limit: 5), failures: failures)
    }

    static func formatted(_ facts: [CoachFoodFact], query: String, failures: [String] = []) -> String {
        guard !facts.isEmpty else {
            if !failures.isEmpty {
                return "Food lookup unavailable for \"\(query)\" (\(failures.joined(separator: "; "))). Say the database did not respond. Do not invent label values; ask for the label or a photo if exact numbers matter."
            }
            return "No database match for \"\(query)\". Do not invent label values; ask for the label or a photo if exact numbers matter."
        }
        let quality = matchQuality(facts, query: query)
        if quality == .none {
            return "No database match for \"\(query)\". Returned products matched a brand or generic word but not the named product. Do not invent label values; ask for the label or a photo if exact numbers matter."
        }
        let lines = facts.enumerated().map { index, fact in "\(index + 1). \(fact.line)" }
        let heading: String
        let footer: String
        switch quality {
        case .exact:
            heading = "Exact database match for \"\(query)\""
            footer = "The package may have been reformulated; name the source and serving. Use the calculator for totals. Sum only nutrients listed for every item; when any label is partial, call the result a partial total and name what is missing."
        case .candidates:
            heading = "Candidate database matches for \"\(query)\" — no exact current label is confirmed"
            footer = "Do not use candidates in an exact total. Ask for the flavor, package label, or a photo when exact numbers matter."
        case .none:
            // Guarded above; retained so the classification stays total.
            heading = "No database match for \"\(query)\""
            footer = "Do not invent label values."
        }
        return """
        \(heading):
        \(lines.joined(separator: "\n"))
        \(footer) Added sugar is listed only when the label reports it.
        """
    }

    enum MatchQuality: String, Equatable, Sendable {
        case exact
        case candidates
        case none
    }

    static func matchQuality(_ facts: [CoachFoodFact], query: String) -> MatchQuality {
        guard let first = facts.first else { return .none }
        let queryWords = matchWords(query)
        guard !queryWords.isEmpty else { return .candidates }
        let firstWords = matchWords(first.name + " " + first.brand)
        let matchingBrand = facts
            .map { matchWords($0.brand) }
            .filter { !$0.isEmpty && $0.isSubset(of: queryWords) }
            .max { $0.count < $1.count }
        if let matchingBrand {
            let productWords = queryWords.subtracting(matchingBrand)
            guard !productWords.isEmpty else { return .candidates }
            let productCoverage = Double(productWords.intersection(firstWords).count)
                / Double(productWords.count)
            if productCoverage < 0.35 { return .none }
            guard productCoverage >= 0.75 else { return .candidates }
        } else {
            let coverage = Double(queryWords.intersection(firstWords).count)
                / Double(queryWords.count)
            guard coverage >= 0.75 else { return .candidates }
            if !first.brand.isEmpty { return .candidates }
        }

        let competing = facts.dropFirst().filter {
            let words = matchWords($0.name + " " + $0.brand)
            return Double(queryWords.intersection(words).count) / Double(queryWords.count) >= 0.75
        }
        if competing.contains(where: { !nutrientsAgree(first, $0) }) {
            return .candidates
        }
        return .exact
    }

    static func rankedFacts(
        _ facts: [CoachFoodFact],
        query: String,
        limit: Int
    ) -> [CoachFoodFact] {
        let queryWords = matchWords(query)
        let isBrandedQuery = facts.contains {
            let brand = matchWords($0.brand)
            return !brand.isEmpty && brand.isSubset(of: queryWords)
        }
        var seen = Set<String>()
        return facts
            .compactMap { fact -> (fact: CoachFoodFact, score: Double)? in
                let key = "\(fact.name.lowercased())|\(fact.brand.lowercased())|\(fact.servingDescription.lowercased())|\(fact.source.lowercased())"
                guard seen.insert(key).inserted else { return nil }
                let words = matchWords(fact.name + " " + fact.brand)
                let coverage = queryWords.isEmpty
                    ? 0
                    : Double(queryWords.intersection(words).count) / Double(queryWords.count)
                let precision = words.isEmpty
                    ? 0
                    : Double(queryWords.intersection(words).count) / Double(words.count)
                let sourceFit = isBrandedQuery
                    ? 0
                    : (fact.brand.isEmpty ? 0.5 : -0.5)
                return (fact, coverage * 10 + precision + sourceFit)
            }
            .sorted { $0.score > $1.score }
            .prefix(max(limit, 0))
            .map { $0.fact }
    }

    private static func matchWords(_ text: String) -> Set<String> {
        let ignored: Set<String> = [
            "and", "bar", "bars", "brand", "flavor", "flavored", "flavoured",
            "food", "foods", "from", "organic", "product", "snack", "style",
            "the", "with"
        ]
        return Set(
            text.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { $0.count >= 2 && !ignored.contains($0) }
        )
    }

    private static func nutrientsAgree(_ lhs: CoachFoodFact, _ rhs: CoachFoodFact) -> Bool {
        func agrees(_ a: Double?, _ b: Double?, tolerance: Double) -> Bool {
            guard let a, let b else { return true }
            return abs(a - b) <= tolerance
        }
        return agrees(lhs.calories, rhs.calories, tolerance: 10)
            && agrees(lhs.proteinGrams, rhs.proteinGrams, tolerance: 2)
            && agrees(lhs.fiberGrams, rhs.fiberGrams, tolerance: 2)
            && agrees(lhs.totalSugarGrams, rhs.totalSugarGrams, tolerance: 2)
            && agrees(lhs.fatGrams, rhs.fatGrams, tolerance: 2)
    }

    static func usdaSearchURL(query: String, key: String = CoachSecrets.usdaKey()) -> URL? {
        var components = URLComponents(string: "https://api.nal.usda.gov/fdc/v1/foods/search")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: key),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "8"),
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
            URLQueryItem(name: "page_size", value: "8"),
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

    static func fetch(
        _ url: URL?,
        session: URLSession,
        accept: String = "application/json"
    ) async -> Result<Data, FetchFailure> {
        guard let url else { return .failure(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(accept, forHTTPHeaderField: "Accept")
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

struct CoachEvidenceRecord: Equatable, Sendable {
    var pmid: String
    var title: String
    var journal: String
    var year: String
    var abstract: String

    var line: String {
        let publication = [journal, year].filter { !$0.isEmpty }.joined(separator: ", ")
        let citation = publication.isEmpty
            ? "\(title). PMID \(pmid)."
            : "\(title). \(publication). PMID \(pmid)."
        guard !abstract.isEmpty else { return citation }
        return citation + "\nAbstract: " + abstract
    }
}

/// PubMed, so "the evidence shows" can be followed by a citation that exists.
/// XML keeps each PMID attached to its own title and abstract; loose text blocks
/// previously allowed the model to pair a title with an unrelated PMID.
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
            return "No PubMed results for \"\(cleaned)\"."
        }
        let records = await fetchRecords(ids: ids, session: session)
        guard !records.isEmpty else {
            return "PubMed records unavailable for \"\(cleaned)\"."
        }
        return """
        PubMed results for "\(cleaned)":
        \(records.enumerated().map { "\($0.offset + 1). \($0.element.line)" }.joined(separator: "\n\n"))
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

    static func fetchRecords(ids: [String], session: URLSession) async -> [CoachEvidenceRecord] {
        var components = URLComponents(string: "\(baseURL)/efetch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: ids.joined(separator: ",")),
            URLQueryItem(name: "rettype", value: "abstract"),
            URLQueryItem(name: "retmode", value: "xml"),
            URLQueryItem(name: "tool", value: "DailyHealthScore")
        ]
        guard case .success(let data) = await CoachFoodService.fetch(
            components?.url,
            session: session,
            accept: "application/xml"
        ) else {
            return []
        }
        return PubMedParser.records(fromXML: data)
    }
}

enum PubMedParser {
    static func ids(fromSearchJSON data: Data) -> [String] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["esearchresult"] as? [String: Any],
              let ids = result["idlist"] as? [String] else { return [] }
        return ids
    }

    static func records(fromXML data: Data) -> [CoachEvidenceRecord] {
        let delegate = PubMedXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return [] }
        return delegate.records
    }
}

private final class PubMedXMLDelegate: NSObject, XMLParserDelegate {
    private enum Field: Equatable {
        case pmid
        case title
        case journal
        case year
        case medlineDate
        case abstractText(label: String?)
    }

    private var stack: [String] = []
    private var field: Field?
    private var buffer = ""
    private var current: CoachEvidenceRecord?
    private var abstractParts: [String] = []
    private(set) var records: [CoachEvidenceRecord] = []

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        stack.append(elementName)
        if elementName == "PubmedArticle" {
            current = CoachEvidenceRecord(pmid: "", title: "", journal: "", year: "", abstract: "")
            abstractParts = []
        }
        guard current != nil, field == nil else { return }
        switch elementName {
        case "PMID" where current?.pmid.isEmpty == true:
            begin(.pmid)
        case "ArticleTitle":
            begin(.title)
        case "Title" where stack.dropLast().last == "Journal":
            begin(.journal)
        case "Year" where stack.contains("PubDate") && current?.year.isEmpty == true:
            begin(.year)
        case "MedlineDate" where stack.contains("PubDate") && current?.year.isEmpty == true:
            begin(.medlineDate)
        case "AbstractText":
            begin(.abstractText(label: attributeDict["Label"]))
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard field != nil else { return }
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if let field, closes(field, elementName: elementName) {
            commit(field, text: collapsed(buffer))
            self.field = nil
            buffer = ""
        }
        if elementName == "PubmedArticle", var record = current {
            record.abstract = limitedAbstract(abstractParts.joined(separator: " "))
            if !record.pmid.isEmpty, !record.title.isEmpty {
                records.append(record)
            }
            current = nil
            abstractParts = []
        }
        if !stack.isEmpty { stack.removeLast() }
    }

    private func begin(_ field: Field) {
        self.field = field
        buffer = ""
    }

    private func closes(_ field: Field, elementName: String) -> Bool {
        switch field {
        case .pmid: return elementName == "PMID"
        case .title: return elementName == "ArticleTitle"
        case .journal: return elementName == "Title"
        case .year: return elementName == "Year"
        case .medlineDate: return elementName == "MedlineDate"
        case .abstractText: return elementName == "AbstractText"
        }
    }

    private func commit(_ field: Field, text: String) {
        guard var record = current else { return }
        switch field {
        case .pmid:
            record.pmid = text
        case .title:
            record.title = text
        case .journal:
            record.journal = text
        case .year:
            record.year = text
        case .medlineDate:
            record.year = firstFourDigitYear(in: text)
        case .abstractText(let label):
            let prefix = label.map { "\($0): " } ?? ""
            if !text.isEmpty { abstractParts.append(prefix + text) }
        }
        current = record
    }

    private func collapsed(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private func limitedAbstract(_ text: String, maxCharacters: Int = 1_100) -> String {
        guard text.count > maxCharacters else { return text }
        let prefix = text.prefix(maxCharacters - 1)
        if let space = prefix.lastIndex(of: " ") {
            return String(prefix[..<space]) + "…"
        }
        return String(prefix) + "…"
    }

    private func firstFourDigitYear(in text: String) -> String {
        let pattern = #"(?:19|20)[0-9]{2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              let range = Range(match.range, in: text) else {
            return ""
        }
        return String(text[range])
    }
}
