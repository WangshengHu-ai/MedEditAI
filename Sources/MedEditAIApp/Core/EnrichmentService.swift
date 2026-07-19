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
    /// 云端失败时的离线兜底，保证结果字段不为空。
    private static let offline = LocalDeterministicLLM()

    init(llm: LLMProviding, topicScheme: ClassificationScheme, customStudyTerms: [String], impactFactorByJournal: [String: String]) {
        self.llm = llm
        self.topicScheme = topicScheme
        self.customStudyTerms = customStudyTerms
        self.impactFactorByJournal = impactFactorByJournal
    }

    func enrich(record: PubMedRecord) async -> ArticleDraft {
        let rawText = [record.title, record.abstract, record.keywords.joined(separator: " "), record.meshTerms.joined(separator: " ")].joined(separator: " ")
        let study = ClassificationEngine.classifyStudyDesign(in: rawText, customTerms: customStudyTerms)

        var titleCN = ""
        var abstractCN = ""
        let request = TranslationRequest(title: record.title, abstract: record.abstract, keywords: record.keywords)
        let translation = (try? await llm.translate(request)) ?? (try? await Self.offline.translate(request))
        titleCN = translation?.titleCN ?? ""
        abstractCN = translation?.abstractCN ?? ""

        let candidatePaths = ClassificationEngine.flattenPaths(in: topicScheme)
        let classification = (try? await llm.classifyTopic(title: record.title, abstract: record.abstract, candidatePaths: candidatePaths))
            ?? (try? await Self.offline.classifyTopic(title: record.title, abstract: record.abstract, candidatePaths: candidatePaths))
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

    private func makeCitation(from record: PubMedRecord) -> String {
        let authorText = record.authors.prefix(2).joined(separator: ", ") + (record.authors.count > 2 ? " et al" : "")
        let doiSuffix = record.doi.map { " DOI: \($0)" } ?? ""
        return "\(authorText). \(record.title). \(record.journal). \(record.pubDate).\(doiSuffix)"
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
