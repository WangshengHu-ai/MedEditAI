import Foundation

/// 导入数据的类型判定。
enum ImportKind: String, Codable, Hashable {
    case articles        // 文献清单（每行一篇）
    case classification  // 分类字典（四级主题树）
    case unknown
}

/// 导入字段优先级：用于在 UI 中提示“必需/建议/可选”。
enum ImportFieldPriority: String, Codable, Hashable {
    case required
    case recommended
    case optional
}

/// 底层模型可映射的规范字段（用于确认界面的下拉选择）。
struct CanonicalField: Identifiable, Hashable {
    let id: String   // 规范字段 key，"" 表示忽略
    let label: String
    let hint: String
    let priority: ImportFieldPriority

    init(id: String, label: String, hint: String = "", priority: ImportFieldPriority = .optional) {
        self.id = id
        self.label = label
        self.hint = hint
        self.priority = priority
    }
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
        .init(id: "", label: "忽略此列", hint: "该列不会导入到文献数据模型。"),
        .init(id: "topic", label: "主题分类", hint: "文章所属的主题词条（可用于主题树筛选和分组导出）。建议源列名：主题 / 主题分类。", priority: .recommended),
        .init(id: "titleEN", label: "标题（英文）", hint: "文献英文标题。导入必需字段（至少需要一列映射到它）。建议源列名：标题 / Title。", priority: .required),
        .init(id: "titleCN", label: "标题（中文）", hint: "人工或 AI 翻译后的中文标题。可空，后续可由 AI 加工补全。", priority: .optional),
        .init(id: "abstractEN", label: "摘要（原文）", hint: "原始摘要（通常为英文），用于 AI 翻译和分类推断。建议源列名：摘要原文 / Abstract。", priority: .recommended),
        .init(id: "abstractCN", label: "摘要（中文）", hint: "中文摘要。若未提供，可在 AI 加工阶段自动生成。", priority: .optional),
        .init(id: "keywords", label: "关键词", hint: "关键词字符串（可分号分隔），用于检索和 AI 上下文增强。"),
        .init(id: "authors", label: "作者", hint: "作者信息（通常为逗号分隔），用于卡片展示和引用。", priority: .recommended),
        .init(id: "date", label: "发表日期", hint: "发表日期或年份（支持文本格式）。用于排序和导出。", priority: .recommended),
        .init(id: "studyDesign", label: "研究类型", hint: "研究设计/类型（如 RCT、队列、综述）。可留空，后续由规则或 AI 推断。", priority: .recommended),
        .init(id: "journal", label: "期刊", hint: "期刊名称。用于 IF 匹配。", priority: .recommended),
        .init(id: "impactFactor", label: "影响因子", hint: "期刊 IF 数值。可由导入 IF 数据集后自动回填。"),
        .init(id: "pmid", label: "PMID", hint: "PubMed ID。用于溯源、去重和外链定位。", priority: .recommended),
        .init(id: "url", label: "原文链接", hint: "DOI/全文 URL，用于导出交付和跳转查看。", priority: .recommended),
        .init(id: "abstractLink", label: "摘要链接", hint: "摘要页链接（如 PubMed 页面），用于导出交付字段。"),
        .init(id: "note", label: "备注", hint: "人工补充说明、复核记录、客户关注点等。")
    ]

    /// 文献导入时必须命中的底层字段（当前最小集合：英文标题）。
    static var requiredImportFieldIDs: Set<String> {
        Set(canonicalFields.filter { $0.priority == .required }.map(\.id))
    }

    static func label(for field: String) -> String {
        canonicalFields.first(where: { $0.id == field })?.label ?? field
    }

    /// 分类字典列角色目录（下拉选项），用于「导入分类字典」确认界面让用户指定每列对应的层级。
    static let classificationFieldOptions: [CanonicalField] = [
        .init(id: "", label: "忽略此列"),
        .init(id: "topic", label: "主题（一级）"),
        .init(id: "secondary", label: "次级菜单（二级）"),
        .init(id: "tertiary", label: "三级菜单（三级）"),
        .init(id: "quaternary", label: "四级菜单（叶子词条）"),
        .init(id: "presentation", label: "呈现方式"),
        .init(id: "note", label: "文献备注")
    ]

    static func analyze(rows: [[String]]) -> ImportAnalysis {
        if let headerIndex = classificationHeaderIndex(in: rows) {
            let headers = rows[headerIndex]
            let sampleRow = firstDataRow(in: rows, after: headerIndex)
            let proposals = headers.enumerated().map { index, header -> ColumnProposal in
                ColumnProposal(
                    sourceHeader: header,
                    field: defaultClassificationRole(for: header),
                    sample: index < sampleRow.count ? sampleRow[index] : ""
                )
            }
            let scheme = classificationScheme(rows: rows, headerIndex: headerIndex, proposals: proposals)
            return ImportAnalysis(
                kind: .classification,
                rows: rows,
                headerIndex: headerIndex,
                proposals: proposals,
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

    /// 按（用户调整后的）列角色建议构建分类字典树。
    static func classificationScheme(from analysis: ImportAnalysis, proposals: [ColumnProposal]) -> ClassificationScheme {
        classificationScheme(rows: analysis.rows, headerIndex: analysis.headerIndex, proposals: proposals)
    }

    private static func classificationScheme(rows: [[String]], headerIndex: Int, proposals: [ColumnProposal]) -> ClassificationScheme {
        var mapping: [String: String] = [:]
        for proposal in proposals where !proposal.field.isEmpty {
            mapping[proposal.sourceHeader] = proposal.field
        }
        return ClassificationEngine.buildTree(from: Array(rows[headerIndex...]), columnRoles: mapping)
    }

    /// 根据列名猜测默认分类层级角色，供用户在确认界面进一步调整。
    private static func defaultClassificationRole(for header: String) -> String {
        let normalized = header.replacingOccurrences(of: " ", with: "")
        if normalized.contains("四级") { return "quaternary" }
        if normalized.contains("三级") { return "tertiary" }
        if normalized.contains("次级") { return "secondary" }
        if normalized.contains("呈现") { return "presentation" }
        if normalized.contains("备注") { return "note" }
        if normalized.contains("主题") { return "topic" }
        return ""
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
