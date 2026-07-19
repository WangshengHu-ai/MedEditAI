import Foundation

enum PubMedError: Error, LocalizedError {
    case invalidURL
    case emptyResult
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "PubMed 请求地址非法"
        case .emptyResult: "检索结果为空"
        case .network(let message): "网络错误：\(message)"
        }
    }
}

/// 与 PubMed 网页一致的排序方式（映射到 E-utilities esearch 的 sort 值）。
enum PubMedSort: String, CaseIterable, Identifiable, Codable {
    case bestMatch = "relevance"
    case pubDate = "pub_date"
    case firstAuthor = "Author"
    case journal = "JournalName"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bestMatch: "最佳匹配"
        case .pubDate: "出版日期"
        case .firstAuthor: "第一作者"
        case .journal: "期刊名称"
        }
    }
}

/// 一次检索的结果：命中总数 + 当前页 PMID 列表。
struct PubMedSearchResult: Hashable {
    let total: Int
    let ids: [String]
}

protocol PubMedFetching {
    func search(query: String, sort: PubMedSort, retstart: Int, retmax: Int) async throws -> PubMedSearchResult
    func fetch(pmids: [String]) async throws -> [PubMedRecord]
}

/// 真实调用 NCBI E-utilities（esearch / efetch）。遵守限流：串行 + 间隔。
final class PubMedService: PubMedFetching {
    private let session: URLSession
    private let apiKey: String?
    private let baseURL = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils"
    private let minInterval: TimeInterval

    init(session: URLSession = .shared, apiKey: String? = nil) {
        self.session = session
        self.apiKey = apiKey
        self.minInterval = apiKey == nil ? 0.34 : 0.1
    }

    func search(query: String, sort: PubMedSort = .bestMatch, retstart: Int = 0, retmax: Int = 25) async throws -> PubMedSearchResult {
        var components = URLComponents(string: "\(baseURL)/esearch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "term", value: query),
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "retstart", value: "\(max(0, retstart))"),
            URLQueryItem(name: "retmax", value: "\(max(1, retmax))"),
            URLQueryItem(name: "retmode", value: "json")
        ] + apiKeyItems()
        guard let url = components?.url else { throw PubMedError.invalidURL }

        let (data, _) = try await session.data(from: url)
        return Self.parseESearchResult(from: data)
    }

    func fetch(pmids: [String]) async throws -> [PubMedRecord] {
        guard !pmids.isEmpty else { throw PubMedError.emptyResult }
        var components = URLComponents(string: "\(baseURL)/efetch.fcgi")
        components?.queryItems = [
            URLQueryItem(name: "db", value: "pubmed"),
            URLQueryItem(name: "id", value: pmids.joined(separator: ",")),
            URLQueryItem(name: "retmode", value: "xml")
        ] + apiKeyItems()
        guard let url = components?.url else { throw PubMedError.invalidURL }

        try await Task.sleep(nanoseconds: UInt64(minInterval * 1_000_000_000))
        let (data, _) = try await session.data(from: url)
        let xml = String(decoding: data, as: UTF8.self)
        return PubMedXMLParser.parseArticles(xml)
    }

    static func parseESearchIDs(from data: Data) -> [String] {
        parseESearchResult(from: data).ids
    }

    static func parseESearchResult(from data: Data) -> PubMedSearchResult {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = object["esearchresult"] as? [String: Any]
        else { return PubMedSearchResult(total: 0, ids: []) }
        let ids = (result["idlist"] as? [String]) ?? []
        let total = Int((result["count"] as? String) ?? "") ?? ids.count
        return PubMedSearchResult(total: total, ids: ids)
    }

    private func apiKeyItems() -> [URLQueryItem] {
        guard let apiKey, !apiKey.isEmpty else { return [] }
        return [URLQueryItem(name: "api_key", value: apiKey)]
    }
}
