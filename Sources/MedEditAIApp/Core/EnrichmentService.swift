import Foundation

struct EnrichmentProgress {
    let processed: Int
    let total: Int
    var fraction: Double { total == 0 ? 0 : Double(processed) / Double(total) }
}

/// 编排真实加工流水线：翻译(LLM) + 研究设计(规则) + 主题分类(LLM) + IF 匹配。
final class EnrichmentService {
    private let llm: LLMProviding
    private let topicScheme: ClassificationScheme
    private let customStudyTerms: [String]
    private let impactFactorByJournal: [String: String]
    init(llm: LLMProviding, topicScheme: ClassificationScheme, customStudyTerms: [String], impactFactorByJournal: [String: String]) {
        self.llm = llm
        self.topicScheme = topicScheme
        self.customStudyTerms = customStudyTerms
        self.impactFactorByJournal = impactFactorByJournal
    }

    func enrich(record: PubMedRecord) async -> ArticleDraft {
        let rawText = [record.title, record.abstract, record.keywords.joined(separator: " "), record.meshTerms.joined(separator: " ")].joined(separator: " ")
        let study = await resolveStudyType(rawText: rawText, title: record.title, abstract: record.abstract)

        var titleCN = ""
        var abstractCN = ""
        let request = TranslationRequest(title: record.title, abstract: record.abstract, keywords: record.keywords)
        if let translation = try? await llm.translate(request) {
            titleCN = translation.titleCN
            abstractCN = translation.abstractCN
        }

        let candidatePaths = ClassificationEngine.flattenPaths(in: topicScheme)
        let classification = try? await llm.classifyTopic(title: record.title, abstract: record.abstract, candidatePaths: candidatePaths)
        let topicLeaf = classification.map { leaf(of: $0.topicPath) } ?? "未分类"

        let confidence = min(study.confidence, classification?.confidence ?? study.confidence)
        let impactFactor = impactFactorByJournal[normalize(record.journal)]

        return ArticleDraft(
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
            product: ArticleProcessor.inferProduct(from: rawText),
            evidence: study.evidenceLevel,
            note: confidence < 0.7 ? "低置信度，建议人工复核。" : "自动加工完成。",
            keywords: record.keywords.isEmpty ? nil : record.keywords.joined(separator: ", ")
        )
    }

    func enrichBatch(records: [PubMedRecord], onProgress: ((EnrichmentProgress) -> Void)? = nil) async -> [ArticleDraft] {
        var drafts: [ArticleDraft] = []
        for (index, record) in records.enumerated() {
            let draft = await enrich(record: record)
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
    private func resolveStudyType(rawText: String, title: String, abstract: String) async -> StudyDesignResult {
        if let local = ClassificationEngine.matchCustomStudyTerm(in: rawText, customTerms: customStudyTerms) {
            return local
        }
        if let ai = try? await llm.classifyStudyType(title: title, abstract: abstract, candidateTerms: customStudyTerms),
           !ai.studyType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
