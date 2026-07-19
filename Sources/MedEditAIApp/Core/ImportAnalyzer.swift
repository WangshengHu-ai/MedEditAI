import Foundation

/// 导入数据的类型判定。
enum ImportKind: String, Codable, Hashable {
    case articles        // 文献清单（每行一篇）
    case classification  // 分类字典（四级主题树）
    case unknown
}

/// 底层模型可映射的规范字段（用于确认界面的下拉选择）。
struct CanonicalField: Identifiable, Hashable {
    let id: String   // 规范字段 key，"" 表示忽略
    let label: String
}

/// 单个源列 → 规范字段的映射建议，用户可在确认界面调整。
struct ColumnProposal: Identifiable, Hashable {
    let id: UUID
    let sourceHeader: String
    var field: String     // 规范字段 key，"" 表示忽略
    let sample: String

    init(id: UUID = UUID(), sourceHeader: String, field: String, sample: String) {
        self.id = id
        self.sourceHeader = sourceHeader
        self.field = field
        self.sample = sample
    }
}

/// 一次导入的分析结果，供用户确认与调整。
struct ImportAnalysis: Identifiable, Hashable {
    let id: UUID
    let kind: ImportKind
    let rows: [[String]]
    let headerIndex: Int
    var proposals: [ColumnProposal]
    let classificationPathCount: Int

    init(
        id: UUID = UUID(),
        kind: ImportKind,
        rows: [[String]],
        headerIndex: Int,
        proposals: [ColumnProposal] = [],
        classificationPathCount: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.rows = rows
        self.headerIndex = headerIndex
        self.proposals = proposals
        self.classificationPathCount = classificationPathCount
    }

    var articleCountEstimate: Int {
        guard kind == .articles, rows.indices.contains(headerIndex) else { return 0 }
        return rows.dropFirst(headerIndex + 1).filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }.count
    }
}

/// 分析导入文件结构，推断类型并给出列映射建议。
enum ImportAnalyzer {
    /// 可映射的底层规范字段目录（下拉选项）。
    static let canonicalFields: [CanonicalField] = [
        .init(id: "", label: "忽略此列"),
        .init(id: "topic", label: "主题分类"),
        .init(id: "titleEN", label: "标题（英文）"),
        .init(id: "titleCN", label: "标题（中文）"),
        .init(id: "abstractEN", label: "摘要（原文）"),
        .init(id: "abstractCN", label: "摘要（中文）"),
        .init(id: "keywords", label: "关键词"),
        .init(id: "authors", label: "作者"),
        .init(id: "date", label: "发表日期"),
        .init(id: "studyDesign", label: "研究类型"),
        .init(id: "journal", label: "期刊"),
        .init(id: "impactFactor", label: "影响因子"),
        .init(id: "pmid", label: "PMID"),
        .init(id: "url", label: "原文链接"),
        .init(id: "abstractLink", label: "摘要链接"),
        .init(id: "note", label: "备注")
    ]

    static func label(for field: String) -> String {
        canonicalFields.first(where: { $0.id == field })?.label ?? field
    }

    static func analyze(rows: [[String]]) -> ImportAnalysis {
        if let headerIndex = classificationHeaderIndex(in: rows) {
            let scheme = ClassificationEngine.buildTree(from: Array(rows[headerIndex...]))
            return ImportAnalysis(
                kind: .classification,
                rows: rows,
                headerIndex: headerIndex,
                classificationPathCount: ClassificationEngine.flattenPaths(in: scheme).count
            )
        }

        if let headerIndex = articleHeaderIndex(in: rows) {
            let headers = rows[headerIndex]
            let mapping = ColumnMappingEngine.buildImportMapping(from: headers, requiredFields: ["titleEN"])
            let sampleRow = firstDataRow(in: rows, after: headerIndex)
            let proposals = headers.enumerated().map { index, header -> ColumnProposal in
                ColumnProposal(
                    sourceHeader: header,
                    field: mapping[header] ?? "",
                    sample: index < sampleRow.count ? sampleRow[index] : ""
                )
            }
            return ImportAnalysis(kind: .articles, rows: rows, headerIndex: headerIndex, proposals: proposals)
        }

        return ImportAnalysis(kind: .unknown, rows: rows, headerIndex: 0)
    }

    /// 按（用户调整后的）建议应用映射，生成文献草稿。
    static func articles(from analysis: ImportAnalysis, proposals: [ColumnProposal]) -> [ArticleDraft] {
        var mapping: [String: String] = [:]
        for proposal in proposals where !proposal.field.isEmpty {
            mapping[proposal.sourceHeader] = proposal.field
        }
        return DocumentService.articles(fromRows: analysis.rows, headerIndex: analysis.headerIndex, mapping: mapping)
    }

    // MARK: - Detection

    private static func classificationHeaderIndex(in rows: [[String]]) -> Int? {
        rows.firstIndex { row in
            let hasTopic = row.contains { $0.contains("主题") }
            let hasSubLevels = row.contains { cell in
                cell.contains("次级菜单") || cell.contains("三级菜单") || cell.contains("四级菜单")
            }
            return hasTopic && hasSubLevels
        }
    }

    private static func articleHeaderIndex(in rows: [[String]]) -> Int? {
        rows.firstIndex { row in
            row.contains { $0.contains("标题") || $0.lowercased().contains("title") }
        }
    }

    private static func firstDataRow(in rows: [[String]], after headerIndex: Int) -> [String] {
        for row in rows.dropFirst(headerIndex + 1) where row.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            return row
        }
        return []
    }
}
