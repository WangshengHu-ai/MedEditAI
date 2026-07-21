import Foundation

/// 导出/PPT 占位符可选字段目录（规范字段 id，供导出列映射与 PPT 占位符映射复用）。
enum ExportFieldCatalog {
    static let fields: [CanonicalField] = [
        .init(id: "sequence", label: "序号", hint: "行序号，从 1 开始自动编号。"),
        .init(id: "topic", label: "主题分类", hint: "文章所属主题词条。"),
        .init(id: "titleEN", label: "标题（英文）", hint: "文献英文标题。"),
        .init(id: "titleCN", label: "标题（中文）", hint: "中文标题。"),
        .init(id: "abstractEN", label: "摘要（原文）", hint: "英文原始摘要。"),
        .init(id: "abstractCN", label: "摘要（中文）", hint: "中文摘要。"),
        .init(id: "abstractLink", label: "摘要链接", hint: "指向原文/摘要页的链接。"),
        .init(id: "authors", label: "作者", hint: "作者列表。"),
        .init(id: "date", label: "发表日期", hint: "发表日期或年份。"),
        .init(id: "studyDesign", label: "研究类型", hint: "研究设计/类型。"),
        .init(id: "journal", label: "期刊", hint: "期刊名称。"),
        .init(id: "impactFactor", label: "影响因子", hint: "期刊 IF 数值。"),
        .init(id: "quartile", label: "分区", hint: "期刊分区（Q1-Q4）。"),
        .init(id: "pmid", label: "PMID", hint: "PubMed 唯一标识。"),
        .init(id: "url", label: "原文链接", hint: "DOI 或全文 URL。"),
        .init(id: "product", label: "研究产品", hint: "识别出的产品/干预措施。"),
        .init(id: "evidence", label: "证据等级", hint: "研究设计对应的证据等级。"),
        .init(id: "citation", label: "参考文献引文", hint: "格式化后的引用文本。"),
        .init(id: "keywords", label: "关键词", hint: "关键词列表。"),
        .init(id: "note", label: "备注", hint: "人工备注。")
    ]

    static func label(for id: String) -> String {
        fields.first(where: { $0.id == id })?.label ?? id
    }
}

/// 用户自定义的单个 Excel 导出列：显示列名（表头） + 取值字段 + 是否作为超链接展示。
struct ExportColumnConfig: Codable, Hashable, Identifiable {
    var id: UUID
    var header: String
    var field: String
    var isHyperlink: Bool

    init(id: UUID = UUID(), header: String, field: String, isHyperlink: Bool = false) {
        self.id = id
        self.header = header
        self.field = field
        self.isHyperlink = isHyperlink
    }
}

/// 用户自定义的单个 PPT 占位符映射：模板里的 {{占位符}} 文本 + 取值字段。
struct PPTPlaceholderMapping: Codable, Hashable, Identifiable {
    var id: UUID
    var placeholder: String
    var field: String

    init(id: UUID = UUID(), placeholder: String, field: String) {
        self.id = id
        self.placeholder = placeholder
        self.field = field
    }
}

/// 产品内可直接编辑的 PPT 样式模板，不依赖外部 .pptx 文件。
struct PPTVisualTemplate: Codable, Hashable {
    var name: String
    var accentHex: String
    var metadataBackgroundHex: String
    var ctaText: String
    var abstractPrefix: String
    var citationPrefix: String
    var disclaimerText: String
    /// 字体名称（如 PingFang SC / Helvetica Neue / Arial），应用于导出 PPTX 的主题字体和所有文本框。
    var fontFamily: String
    /// 以下字号均为“磅值”（pt），与导出 PPTX 中的真实字号一一对应；预览会按比例缩放展示。
    var topicFontSize: Double
    var titleFontSize: Double
    var subtitleFontSize: Double
    var bodyFontSize: Double
    var metadataFontSize: Double
    var captionFontSize: Double

    init(
        name: String = "MedEditAI Onepage",
        accentHex: String = "#0E9F9F",
        metadataBackgroundHex: String = "#EAF8F7",
        ctaText: String = "点击查看原文链接",
        abstractPrefix: String = "摘要：",
        citationPrefix: String = "参考文献：",
        disclaimerText: String = "*版权问题暂不提供直接下载，如有学术交流需要，请联系内部人员",
        fontFamily: String = "Arial",
        topicFontSize: Double = 18,
        titleFontSize: Double = 22,
        subtitleFontSize: Double = 16,
        bodyFontSize: Double = 12,
        metadataFontSize: Double = 11,
        captionFontSize: Double = 9
    ) {
        self.name = name
        self.accentHex = accentHex
        self.metadataBackgroundHex = metadataBackgroundHex
        self.ctaText = ctaText
        self.abstractPrefix = abstractPrefix
        self.citationPrefix = citationPrefix
        self.disclaimerText = disclaimerText
        self.fontFamily = fontFamily
        self.topicFontSize = topicFontSize
        self.titleFontSize = titleFontSize
        self.subtitleFontSize = subtitleFontSize
        self.bodyFontSize = bodyFontSize
        self.metadataFontSize = metadataFontSize
        self.captionFontSize = captionFontSize
    }
}

/// 用户自定义 AI 加工任务：独立的 prompt + 产出字段名，与内置的翻译/研究设计/主题分类等标准任务并行运行。
/// 产出结果写入 `ArticleDraft.customFields[outputFieldKey]`，不覆盖任何标准字段。
struct CustomProcessingTask: Codable, Hashable, Identifiable {
    var id: UUID
    var title: String
    var outputFieldKey: String
    var prompt: String
    var isEnabled: Bool

    init(id: UUID = UUID(), title: String, outputFieldKey: String, prompt: String, isEnabled: Bool = true) {
        self.id = id
        self.title = title
        self.outputFieldKey = outputFieldKey
        self.prompt = prompt
        self.isEnabled = isEnabled
    }
}

/// 单个项目的完整可配置项：AI Prompt、IF 数据集、研究类型词条、主题分类字典、PPT 模板、
/// Excel 导出列、PPT 占位符映射、自定义加工任务。新建项目时以“默认项目配置”为种子。
struct ProjectConfig: Codable, Hashable {
    var promptTemplates: PromptTemplates
    var impactFactorByJournal: [String: String]
    var customStudyTerms: [String]
    var topicScheme: ClassificationScheme?
    var pptTemplatePath: String?
    var pptVisualTemplate: PPTVisualTemplate
    var exportColumns: [ExportColumnConfig]
    var pptPlaceholders: [PPTPlaceholderMapping]
    var customTasks: [CustomProcessingTask]
    /// 产品内 PPT 画板模板（可拖拽的文本框/图片，实时预览）。Optional 以兼容旧持久化数据。
    var pptCanvas: PPTCanvasTemplate?

    init(
        promptTemplates: PromptTemplates = .default,
        impactFactorByJournal: [String: String] = [:],
        customStudyTerms: [String] = [],
        topicScheme: ClassificationScheme? = nil,
        pptTemplatePath: String? = nil,
        pptVisualTemplate: PPTVisualTemplate = .init(),
        exportColumns: [ExportColumnConfig] = ProjectConfig.defaultExportColumns,
        pptPlaceholders: [PPTPlaceholderMapping] = ProjectConfig.defaultPPTPlaceholders,
        customTasks: [CustomProcessingTask] = [],
        pptCanvas: PPTCanvasTemplate? = nil
    ) {
        self.promptTemplates = promptTemplates
        self.impactFactorByJournal = impactFactorByJournal
        self.customStudyTerms = customStudyTerms
        self.topicScheme = topicScheme
        self.pptTemplatePath = pptTemplatePath
        self.pptVisualTemplate = pptVisualTemplate
        self.exportColumns = exportColumns
        self.pptPlaceholders = pptPlaceholders
        self.customTasks = customTasks
        self.pptCanvas = pptCanvas
    }

    static let `default` = ProjectConfig()

    /// 镜像此前硬编码的 11 列交付 Excel，作为默认导出模板。
    static let defaultExportColumns: [ExportColumnConfig] = [
        .init(header: "主题", field: "topic"),
        .init(header: "序号", field: "sequence"),
        .init(header: "标题", field: "titleEN"),
        .init(header: "摘要链接", field: "abstractLink", isHyperlink: true),
        .init(header: "作者", field: "authors"),
        .init(header: "发表日期", field: "date"),
        .init(header: "研究类型", field: "studyDesign"),
        .init(header: "期刊", field: "journal"),
        .init(header: "2025年IF", field: "impactFactor"),
        .init(header: "PMID", field: "pmid"),
        .init(header: "原文链接", field: "url", isHyperlink: true)
    ]

    /// 镜像此前硬编码的 11 个 PPT 占位符，作为默认占位符映射。
    static let defaultPPTPlaceholders: [PPTPlaceholderMapping] = [
        .init(placeholder: "{{topic}}", field: "topic"),
        .init(placeholder: "{{title_en}}", field: "titleEN"),
        .init(placeholder: "{{title_cn}}", field: "titleCN"),
        .init(placeholder: "{{authors}}", field: "authors"),
        .init(placeholder: "{{pub_date}}", field: "date"),
        .init(placeholder: "{{study_type}}", field: "studyDesign"),
        .init(placeholder: "{{journal}}", field: "journal"),
        .init(placeholder: "{{if}}", field: "impactFactor"),
        .init(placeholder: "{{abstract_cn}}", field: "abstractCN"),
        .init(placeholder: "{{citation}}", field: "citation"),
        .init(placeholder: "{{url}}", field: "url")
    ]
}

// MARK: - PPT 画板模板（可视化拖拽编辑，实时预览）

/// 画板元素类型：绑定字段的文本框（随文献数据自动填充）、固定文本框、图片。
enum CanvasElementKind: String, Codable, Hashable {
    case boundText
    case staticText
    case image
}

enum CanvasTextAlignment: String, Codable, Hashable {
    case leading, center, trailing
}

/// 画板上的单个元素。位置/大小单位为“点(pt)”，相对画布左上角。
struct CanvasElement: Codable, Hashable, Identifiable {
    var id: UUID
    var kind: CanvasElementKind
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    /// boundText 绑定的字段 id（见 `ExportFieldCatalog`）。
    var fieldID: String
    /// staticText 的文字内容；boundText 时作为字段值前缀（可空）。
    var text: String
    var fontSize: Double
    var fontFamily: String
    var colorHex: String
    var bold: Bool
    var alignment: CanvasTextAlignment
    /// image 元素的 PNG 图片（base64 编码）。
    var imageBase64: String

    init(
        id: UUID = UUID(),
        kind: CanvasElementKind,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        fieldID: String = "titleEN",
        text: String = "",
        fontSize: Double = 14,
        fontFamily: String = "Arial",
        colorHex: String = "#1A1A1A",
        bold: Bool = false,
        alignment: CanvasTextAlignment = .leading,
        imageBase64: String = ""
    ) {
        self.id = id
        self.kind = kind
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.fieldID = fieldID
        self.text = text
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.colorHex = colorHex
        self.bold = bold
        self.alignment = alignment
        self.imageBase64 = imageBase64
    }
}

/// PPT 画板模板：固定 A4 页面 + 一组自由摆放的元素。
struct PPTCanvasTemplate: Codable, Hashable {
    /// A4 纵向，单位点(pt)，72dpi。
    var pageWidth: Double
    var pageHeight: Double
    var backgroundHex: String
    var elements: [CanvasElement]

    init(
        pageWidth: Double = 595,
        pageHeight: Double = 842,
        backgroundHex: String = "#FFFFFF",
        elements: [CanvasElement] = PPTCanvasTemplate.defaultElements
    ) {
        self.pageWidth = pageWidth
        self.pageHeight = pageHeight
        self.backgroundHex = backgroundHex
        self.elements = elements
    }

    static let `default` = PPTCanvasTemplate()

    /// 默认起始版式：主题标签 + 双语标题 + 作者/期刊 + 中文摘要 + 参考文献 + 链接与版权声明。
    static let defaultElements: [CanvasElement] = [
        .init(kind: .boundText, x: 40, y: 34, width: 515, height: 30, fieldID: "topic",
              fontSize: 18, colorHex: "#0E9F9F", bold: true),
        .init(kind: .boundText, x: 40, y: 72, width: 515, height: 54, fieldID: "titleEN",
              fontSize: 20, colorHex: "#111111", bold: true),
        .init(kind: .boundText, x: 40, y: 128, width: 515, height: 40, fieldID: "titleCN",
              fontSize: 16, colorHex: "#444444"),
        .init(kind: .boundText, x: 40, y: 178, width: 320, height: 20, fieldID: "authors",
              fontSize: 11, colorHex: "#666666"),
        .init(kind: .boundText, x: 40, y: 200, width: 320, height: 20, fieldID: "journal",
              fontSize: 11, colorHex: "#666666"),
        .init(kind: .boundText, x: 380, y: 178, width: 175, height: 42, fieldID: "impactFactor",
              text: "IF ", fontSize: 11, colorHex: "#0E7BA6", alignment: .trailing),
        .init(kind: .boundText, x: 40, y: 240, width: 515, height: 372, fieldID: "abstractCN",
              text: "摘要：", fontSize: 12, colorHex: "#222222"),
        .init(kind: .boundText, x: 40, y: 630, width: 515, height: 64, fieldID: "citation",
              text: "参考文献：", fontSize: 10, colorHex: "#555555"),
        .init(kind: .staticText, x: 40, y: 706, width: 515, height: 24, text: "点击查看原文链接",
              fontSize: 12, colorHex: "#0E9F9F", bold: true),
        .init(kind: .staticText, x: 40, y: 760, width: 515, height: 44,
              text: "*版权问题暂不提供直接下载，如有学术交流需要，请联系内部人员",
              fontSize: 9, colorHex: "#999999")
    ]
}
