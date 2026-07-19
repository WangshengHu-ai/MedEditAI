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

/// 可查看/自定义的 AI 加工 Prompt 模板。占位符：{title} {abstract} {keywords} {candidates}。
struct PromptTemplates: Codable, Hashable {
    var translationSystem: String
    var translationUser: String
    var classificationSystem: String
    var classificationUser: String

    static let `default` = PromptTemplates(
        translationSystem: "You are a precise medical editing assistant. Never fabricate.",
        translationUser: """
        你是医学翻译助手。仅基于给定文本，将标题、摘要、关键词翻译成简体中文，不得编造。
        以 JSON 输出：{"titleCN":"","abstractCN":"","keywordsCN":[]}
        标题：{title}
        摘要：{abstract}
        关键词：{keywords}
        """,
        classificationSystem: "You are a precise medical editing assistant. Never fabricate.",
        classificationUser: """
        从候选主题路径中选择最匹配的一条，仅基于给定文本，未匹配则选择最接近的一条并降低置信度。
        以 JSON 输出：{"topicPath":"","confidence":0.0}
        候选：{candidates}
        标题：{title}
        摘要：{abstract}
        """
    )

    /// 按占位符生成翻译 Prompt（纯函数，便于单元测试）。
    func translationPrompt(title: String, abstract: String, keywords: [String]) -> String {
        translationUser
            .replacingOccurrences(of: "{title}", with: title)
            .replacingOccurrences(of: "{abstract}", with: abstract)
            .replacingOccurrences(of: "{keywords}", with: keywords.joined(separator: "; "))
    }

    /// 按占位符生成主题分类 Prompt（纯函数，便于单元测试）。
    func classificationPrompt(title: String, abstract: String, candidates: [String]) -> String {
        classificationUser
            .replacingOccurrences(of: "{candidates}", with: candidates.joined(separator: " | "))
            .replacingOccurrences(of: "{title}", with: title)
            .replacingOccurrences(of: "{abstract}", with: abstract)
    }
}

/// OpenAI 兼容 Provider（也适配国产兼容端点）。真实 HTTP 调用，用户自持 Key。
struct OpenAICompatibleLLM: LLMProviding {
    let apiKey: String
    let model: String
    let endpoint: URL
    let session: URLSession
    let templates: PromptTemplates

    init(apiKey: String, model: String = "gpt-4o-mini", endpoint: URL = URL(string: "https://api.openai.com/v1/chat/completions")!, session: URLSession = .shared, templates: PromptTemplates = .default) {
        self.apiKey = apiKey
        self.model = model
        self.endpoint = endpoint
        self.session = session
        self.templates = templates
    }

    func translate(_ request: TranslationRequest) async throws -> TranslationResult {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }
        let prompt = templates.translationPrompt(
            title: request.title,
            abstract: request.abstract,
            keywords: request.keywords
        )
        let content = try await complete(system: templates.translationSystem, prompt: prompt)
        guard let data = extractJSON(content)?.data(using: .utf8),
              let result = try? JSONDecoder().decode(TranslationResult.self, from: data) else {
            throw LLMError.badResponse(content)
        }
        return result
    }

    func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult {
        guard !apiKey.isEmpty else { throw LLMError.notConfigured }
        let prompt = templates.classificationPrompt(
            title: title,
            abstract: abstract,
            candidates: candidatePaths
        )
        let content = try await complete(system: templates.classificationSystem, prompt: prompt)
        guard let data = extractJSON(content)?.data(using: .utf8),
              let result = try? JSONDecoder().decode(TopicClassificationResult.self, from: data) else {
            throw LLMError.badResponse(content)
        }
        return result
    }

    private func complete(system: String, prompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let body: [String: Any] = [
            "model": model,
            "temperature": 0,
            "messages": [
                ["role": "system", "content": system],
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

