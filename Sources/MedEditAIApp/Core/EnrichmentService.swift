import Foundation

struct EnrichmentProgress {
    let processed: Int
    let total: Int
    var fraction: Double { total == 0 ? 0 : Double(processed) / Double(total) }
}

/// 编排真实加工流水线：翻译(LLM) + 研究设计(规则/AI) + 主题分类(LLM) + IF 匹配 + 用户自定义加工任务。
/// 标准任务（translate/study/topic/products/metrics）由 `enabledTasks` 真实控制开关，与「AI 加工」页的任务开关一一对应。
final class EnrichmentService {
    private let llm: LLMProviding
    private let topicScheme: ClassificationScheme
    private let customStudyTerms: [String]
    private let impactFactorByJournal: [String: String]
    private let enabledTasks: Set<String>
    private let customTasks: [CustomProcessingTask]

    init(
        llm: LLMProviding,
        topicScheme: ClassificationScheme,
        customStudyTerms: [String],
        impactFactorByJournal: [String: String],
        enabledTasks: Set<String> = ["translate", "study", "topic", "products", "metrics"],
        customTasks: [CustomProcessingTask] = []
    ) {
        self.llm = llm
        self.topicScheme = topicScheme
        self.customStudyTerms = customStudyTerms
        self.impactFactorByJournal = impactFactorByJournal
        self.enabledTasks = enabledTasks
        self.customTasks = customTasks
    }

    func enrich(record: PubMedRecord, onStep: (@Sendable (String) async -> Void)? = nil) async throws -> ArticleDraft {
        let rawText = [record.title, record.abstract, record.keywords.joined(separator: " "), record.meshTerms.joined(separator: " ")].joined(separator: " ")
        let study: StudyDesignResult
        if enabledTasks.contains("study") {
            await onStep?("识别研究设计…")
            study = try await resolveStudyType(rawText: rawText, title: record.title, abstract: record.abstract)
        } else {
            study = StudyDesignResult(design: "", evidenceLevel: "", confidence: 1.0)
        }

        var titleCN = ""
        var abstractCN = ""
        if enabledTasks.contains("translate") {
            await onStep?("翻译标题与摘要…")
            let request = TranslationRequest(title: record.title, abstract: record.abstract, keywords: record.keywords)
            let translation = try await llm.translate(request)
            titleCN = translation.titleCN
            abstractCN = translation.abstractCN
        }

        var topicLeaf = "未分类"
        var topicConfidence: Double?
        if enabledTasks.contains("topic") {
            await onStep?("主题分类…")
            let candidatePaths = ClassificationEngine.flattenPaths(in: topicScheme)
            let classification = try await llm.classifyTopic(title: record.title, abstract: record.abstract, candidatePaths: candidatePaths)
            topicLeaf = leaf(of: classification.topicPath)
            topicConfidence = classification.confidence
        }

        let confidence = min(study.confidence, topicConfidence ?? study.confidence)
        if enabledTasks.contains("metrics") || enabledTasks.contains("products") {
            await onStep?("匹配 IF 与产品…")
        }
        let impactFactor = enabledTasks.contains("metrics") ? impactFactorByJournal[normalize(record.journal)] : nil
        let product = enabledTasks.contains("products") ? ArticleProcessor.inferProduct(from: rawText) : ""

        var draft = ArticleDraft(
            topic: topicLeaf,
            titleEN: record.title,
            titleCN: titleCN,
            abstractEN: record.abstract,
            abstractCN: abstractCN,
            citation: makeCitation(from: record),
            authors: record.authors.joined(separator: ", "),
            date: record.pubDate,
            studyType: study.design,
            journal: record.journal,
            impactFactor: impactFactor,
            quartile: nil,
            pmid: record.pmid,
            url: record.doi.map { "https://doi.org/\($0)" },
            confidence: confidence,
            product: product,
            evidence: study.evidenceLevel,
            note: confidence < 0.7 ? "低置信度，建议人工复核。" : "自动加工完成。",
            keywords: record.keywords.isEmpty ? nil : record.keywords.joined(separator: ", ")
        )

        if !customTasks.isEmpty {
            var fields = draft.customFields ?? [:]
            for task in customTasks where task.isEnabled {
                await onStep?("自定义任务：\(task.title)…")
                let result = try await llm.runCustomTask(
                    promptTemplate: task.prompt, title: record.title, abstract: record.abstract, keywords: record.keywords
                )
                if !result.isEmpty {
                    fields[task.outputFieldKey] = result
                }
            }
            draft.customFields = fields.isEmpty ? nil : fields
        }

        return draft
    }

    func enrichBatch(records: [PubMedRecord], onProgress: ((EnrichmentProgress) -> Void)? = nil) async throws -> [ArticleDraft] {
        var drafts: [ArticleDraft] = []
        for (index, record) in records.enumerated() {
            let draft = try await enrich(record: record)
            drafts.append(draft)
            onProgress?(EnrichmentProgress(processed: index + 1, total: records.count))
        }
        return drafts
    }

    private func leaf(of path: String) -> String {
        path.split(separator: ">").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? path
    }

    /// 研究类型判定顺序：① 命中用户自定义词条（本地关键词匹配，无需联网）；
    /// ② 未命中则调用 AI 基于标题/摘要推断（优先参考自定义词条作为候选，允许自由推断）；
    /// ③ AI 也无法判断时留空，交由人工在复核时补充，不编造。
    private func resolveStudyType(rawText: String, title: String, abstract: String) async throws -> StudyDesignResult {
        if let local = ClassificationEngine.matchCustomStudyTerm(in: rawText, customTerms: customStudyTerms) {
            return local
        }
        let ai = try await llm.classifyStudyType(title: title, abstract: abstract, candidateTerms: customStudyTerms)
        if !ai.studyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return StudyDesignResult(design: ai.studyType, evidenceLevel: "AI 推断", confidence: ai.confidence)
        }
        return StudyDesignResult(design: "", evidenceLevel: "", confidence: 0.5)
    }

    private func makeCitation(from record: PubMedRecord) -> String {
        let authorText = record.authors.prefix(2).joined(separator: ", ") + (record.authors.count > 2 ? " et al" : "")
        let doiSuffix = record.doi.map { " DOI: \($0)" } ?? ""
        return "\(authorText). \(record.title). \(record.journal). \(record.pubDate).\(doiSuffix)"
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
