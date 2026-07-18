import Foundation

struct TranslationRequest {
    let title: String
    let abstract: String
    let keywords: [String]
}

struct TranslationResult: Codable, Hashable {
    let titleCN: String
    let abstractCN: String
    let keywordsCN: [String]
}

struct TopicClassificationResult: Codable, Hashable {
    let topicPath: String
    let confidence: Double
}

/// 可插拔 LLM 能力协议。云端与本地 Provider 都实现它。
protocol LLMProviding {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult
    func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult
}

enum LLMError: Error, LocalizedError {
    case notConfigured
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "LLM 未配置 API Key"
        case .badResponse(let message): "LLM 响应异常：\(message)"
        }
    }
}

/// 离线确定性 Provider：不联网，规则可预测，用于开发、测试与无网络降级。
struct LocalDeterministicLLM: LLMProviding {
    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        TranslationResult(
            titleCN: LocalGlossary.translate(request.title),
            abstractCN: request.abstract.isEmpty ? "" : LocalGlossary.translate(request.abstract),
            keywordsCN: request.keywords.map(LocalGlossary.translate)
        )
    }

    func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult {
        let haystack = (title + " " + abstract).lowercased()
        var best: (path: String, score: Int)?
        for path in candidatePaths {
            let leaf = path.split(separator: ">").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? path
            let tokens = leaf.lowercased().split(whereSeparator: { "—-,，、（）()".contains($0) })
            let score = tokens.reduce(0) { $0 + (haystack.contains($1) ? 1 : 0) }
            if best == nil || score > best!.score {
                best = (path, score)
            }
        }
        let confidence = best.map { $0.score > 0 ? 0.9 : 0.55 } ?? 0.5
        return TopicClassificationResult(topicPath: best?.path ?? (candidatePaths.first ?? "未分类"), confidence: confidence)
    }
}

/// OpenAI 兼容 Provider（也适配国产兼容端点）。真实 HTTP 调用，用户自持 Key。
struct OpenAICompatibleLLM: LLMProviding {
    let apiKey: String
    let model: String
    let endpoint: URL
    let session: URLSession

    init(apiKey: String, model: String = "gpt-4o-mini", endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.session = session
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }
        let prompt = """
        你是医学翻译助手。仅基于给定文本，将标题、摘要、关键词翻译成简体中文，不得编造。
        以 JSON 输出：{"titleCN":"","abstractCN":"","keywordsCN":[]}
        标题：\(request.title)
        摘要：\(request.abstract)
        关键词：\(request.keywords.joined(separator: "; "))
        """
        let content = try await complete(prompt: prompt)
        guard let data = extractJSON(content)?.data(using: .utf8),
              let result = try? JSONDecoder().decode(TranslationResult.self, from: data) else {
            throw LLMError.badResponse(content)
        }
        return result
    }

    func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }
        let prompt = """
        从候选主题路径中选择最匹配的一条，仅基于给定文本，未匹配则选择最接近的一条并降低置信度。
        以 JSON 输出：{"topicPath":"","confidence":0.0}
        候选：\(candidatePaths.joined(separator: " | "))
        标题：\(title)
        摘要：\(abstract)
        """
        let content = try await complete(prompt: prompt)
        guard let data = extractJSON(content)?.data(using: .utf8),
              let result = try? JSONDecoder().decode(TopicClassificationResult.self, from: data) else {
            throw LLMError.badResponse(content)
        }
        return result
    }

    private func complete(prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": "You are a precise medical editing assistant. Never fabricate."],
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await session.data(for: request)
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = object["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw LLMError.badResponse(String(decoding: data, as: UTF8.self))
        }
        return content
    }

    private func extractJSON(_ text: String) -> String? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else { return nil }
        return String(text[start...end])
    }
}

/// 简单本地术语词典，供离线 Provider 使用。
enum LocalGlossary {
    private static let table: [String: String] = [
        "Pulsed field ablation": "脉冲电场消融",
        "pulsed field ablation": "脉冲电场消融",
        "Radiofrequency Ablation": "射频消融",
        "radiofrequency ablation": "射频消融",
        "Electroporation": "电穿孔",
        "electroporation": "电穿孔",
        "atrial fibrillation": "心房颤动",
        "Atrial fibrillation": "心房颤动",
        "ablation": "消融",
        "review": "综述",
        "cardiac": "心脏"
    ]

    static func translate(_ text: String) -> String {
        var result = text
        for (english, chinese) in table.sorted(by: { $0.key.count > $1.key.count }) {
            result = result.replacingOccurrences(of: english, with: chinese)
        }
        if result == text {
            return "【待人工校对】" + text
        }
        return result
    }
}
