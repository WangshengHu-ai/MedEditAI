import Foundation

struct ArticleProcessingContext {
    var customStudyTerms: [String]
    var topicScheme: ClassificationScheme
    var impactFactorByJournal: [String: String]
}

enum ArticleProcessor {
    static func enrich(record: PubMedRecord, context: ArticleProcessingContext) -> ArticleDraft {
        let rawText = [record.title, record.abstract, record.keywords.joined(separator: " "), record.meshTerms.joined(separator: " ")].joined(separator: " ")
        let study = ClassificationEngine.classifyStudyDesign(in: rawText, customTerms: context.customStudyTerms)
        let topic = inferTopic(from: record.title, scheme: context.topicScheme)
        let impactFactor = context.impactFactorByJournal[normalize(record.journal)]

        return ArticleDraft(
            topic: topic,
            titleEN: record.title,
            titleCN: translateTitle(record.title),
            abstractEN: record.abstract,
            abstractCN: translateAbstract(record.abstract),
            citation: makeCitation(from: record),
            authors: record.authors.joined(separator: ", "),
            date: record.pubDate,
            studyType: study.design,
            journal: record.journal,
            impactFactor: impactFactor,
            quartile: nil,
            pmid: record.pmid,
            url: nil,
            confidence: study.confidence,
            product: inferProduct(from: rawText),
            evidence: study.evidenceLevel,
            note: "自动加工结果，可在详情页人工修正。",
            keywords: record.keywords.isEmpty ? nil : record.keywords.joined(separator: ", ")
        )
    }

    static func inferProduct(from text: String) -> String {
        let normalized = normalize(text)
        if normalized.contains("pfa") || normalized.contains("pulsedfield") { return "PFA" }
        if normalized.contains("radiofrequency") || normalized.contains("rf") { return "RF" }
        if normalized.contains("cryo") || normalized.contains("cryoballoon") { return "冷冻球囊" }
        if normalized.contains("electroporation") { return "电穿孔" }
        return "未识别"
    }

    static func renderExportRow(article: ArticleDraft, sequence: Int) -> ExportRow {
        let values: [String: String] = [
            "主题": article.topic,
            "序号": "\(sequence)",
            "标题": article.titleEN,
            "摘要/内容简介详情链接": article.abstractCN,
            "作者": article.authors,
            "发表日期": article.date,
            "研究类型": article.studyType,
            "期刊": article.journal,
            "2025年IF": article.impactFactor ?? "",
            "PMID": article.pmid ?? "",
            "原文链接": article.url ?? ""
        ]
        return ExportRow(values: values, hyperlinks: ["摘要/内容简介详情链接": article.url ?? "", "原文链接": article.url ?? ""])
    }

    /// 与 `renderExportRow` 不同：以“规范字段 id”（见 `ExportFieldCatalog`）为 key，而非固定中文表头，
    /// 供用户自定义 Excel 导出列/PPT 占位符映射时按字段取值。
    static func renderExportFieldValues(article: ArticleDraft, sequence: Int) -> [String: String] {
        var values = [
            "sequence": "\(sequence)",
            "topic": article.topic,
            "titleEN": article.titleEN,
            "titleCN": article.titleCN,
            "abstractEN": article.abstractEN,
            "abstractCN": article.abstractCN,
            "abstractLink": article.url ?? "",
            "authors": article.authors,
            "date": article.date,
            "studyDesign": article.studyType,
            "journal": article.journal,
            "impactFactor": article.impactFactor ?? "",
            "quartile": article.quartile ?? "",
            "pmid": article.pmid ?? "",
            "url": article.url ?? "",
            "product": article.product,
            "evidence": article.evidence,
            "citation": article.citation,
            "keywords": article.keywords ?? "",
            "note": article.note
        ]
        if let customFields = article.customFields {
            values.merge(customFields) { _, new in new }
        }
        return values
    }


    static func renderSlide(article: ArticleDraft) -> RenderedSlide {
        RenderedSlide(
            topic: article.topic,
            titleEN: article.titleEN,
            titleCN: article.titleCN,
            authors: article.authors,
            date: article.date,
            studyType: article.studyType,
            journal: article.journal,
            impactFactor: article.impactFactor ?? "",
            abstract: article.abstractCN,
            citation: article.citation,
            url: article.url
        )
    }

    private static func translateTitle(_ text: String) -> String {
        if text.contains("Pulsed field ablation") { return "脉冲电场消融相关研究" }
        if text.contains("Radiofrequency Ablation") { return "射频消融相关研究" }
        if text.contains("Electroporation") { return "电穿孔相关研究" }
        return "中文标题待人工校对"
    }

    private static func translateAbstract(_ text: String) -> String {
        if text.isEmpty { return "摘要为空，需人工补充。" }
        return "中文摘要已生成（示意）：" + text
    }

    private static func makeCitation(from record: PubMedRecord) -> String {
        let authorText = record.authors.prefix(2).joined(separator: ", ") + (record.authors.count > 2 ? " et al" : "")
        let doiSuffix = record.doi.map { " DOI: \($0)" } ?? ""
        return "\(authorText). \(record.title). \(record.journal). \(record.pubDate).\(doiSuffix)"
    }

    static func inferTopic(from title: String, scheme: ClassificationScheme) -> String {
        let normalizedTitle = normalize(title)
        for path in ClassificationEngine.flattenPaths(in: scheme) {
            let parts = path.split(separator: ">")
            if let leaf = parts.last?.trimmingCharacters(in: .whitespaces) {
                let leafText = String(leaf)
                if normalizedTitle.contains(normalize(leafText)) {
                    return leafText
                }
            }
        }
        return scheme.items.first?.children.first?.children.first?.children.first?.title ?? "未分类"
    }

    private static func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: " ", with: "")
    }
}
