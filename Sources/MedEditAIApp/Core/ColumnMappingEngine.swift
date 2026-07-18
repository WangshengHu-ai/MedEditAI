import Foundation

enum ColumnMappingEngine {
    private static let aliasTable: [String: [String]] = [
        "topic": ["主题", "topic", "分类", "project", "章节"],
        "sequence": ["序号", "seq", "sequence", "number", "编号"],
        "titleEN": ["标题", "title", "title_en", "英文标题", "article title"],
        "titleCN": ["中文标题", "title_cn", "标题中文"],
        "abstractEN": ["摘要/研究简介-原文", "摘要原文", "abstract", "abstract_en", "摘要内容"],
        "abstractCN": ["摘要/研究简介-翻译", "摘要翻译", "abstract_cn", "中文摘要"],
        "authors": ["作者", "author", "authors"],
        "date": ["发表日期", "日期", "pubdate", "publication date"],
        "studyDesign": ["研究类型", "研究设计", "study type", "design"],
        "journal": ["期刊", "journal", "journal name"],
        "impactFactor": ["2025年IF", "if", "impact factor", "impactfactor"],
        "pmid": ["PMID", "pmid", "pubmed id"],
        "url": ["原文链接", "url", "link", "source url"],
        "abstractLink": ["摘要/内容简介详情链接", "摘要链接", "abstract link"],
        "topicCategories": ["主题分类", "topic categories", "categories"],
        "presentation": ["呈现方式", "presentation"],
        "note": ["文献备注", "备注", "note"]
    ]

    static func buildImportMapping(from headers: [String], requiredFields: Set<String>) -> [String: String] {
        let normalizedHeaders = headers.map { normalize($0) }
        var result: [String: String] = [:]

        for (canonical, aliases) in aliasTable {
            if let matchIndex = headers.firstIndex(where: { header in
                let normalized = normalize(header)
                return aliases.contains(where: { normalized.contains(normalize($0)) }) || normalized == normalize(canonical)
            }) {
                result[headers[matchIndex]] = canonical
            }
        }

        for required in requiredFields where !result.values.contains(required) {
            if let fallbackIndex = bestMatchIndex(for: required, in: headers, normalizedHeaders: normalizedHeaders) {
                result[headers[fallbackIndex]] = required
            }
        }

        return result
    }

    static func buildExportHeaders(for template: ExportTemplate) -> [String] {
        template.columns
    }

    static func mapRow(_ row: [String: String], using mapping: [String: String]) -> [String: String] {
        var output: [String: String] = [:]
        for (header, value) in row {
            if let canonical = mapping[header] {
                output[canonical] = value
            }
        }
        return output
    }

    static func mapBack(_ canonicalRow: [String: String], toHeaders headers: [String], using template: ExportTemplate) -> [String: String] {
        var output: [String: String] = [:]
        for header in headers {
            let canonical = header
            if let value = canonicalRow[canonical] {
                output[header] = value
            } else if template.hyperlinkFields.contains(header), let url = canonicalRow["url"] {
                output[header] = url
            } else {
                output[header] = ""
            }
        }
        return output
    }

    private static func normalize(_ text: String) -> String {
        text
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "/", with: "")
    }

    private static func bestMatchIndex(for required: String, in headers: [String], normalizedHeaders: [String]) -> Int? {
        let normalizedRequired = normalize(required)
        var bestScore = 0
        var bestIndex: Int?

        for (index, header) in headers.enumerated() {
            let normalizedHeader = normalizedHeaders[index]
            let score = similarityScore(normalizedRequired, normalizedHeader)
            if score > bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestScore >= 3 ? bestIndex : nil
    }

    private static func similarityScore(_ left: String, _ right: String) -> Int {
        if left == right { return 100 }
        var score = 0
        for character in left where right.contains(character) { score += 1 }
        if right.contains(left) || left.contains(right) { score += 10 }
        return score
    }
}
