import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Navigation & selection
    @Published var selectedSection: AppSection? = .dashboard
    @Published var selectedProject: Project = SampleData.projects[0]
    @Published var selectedArticleID: String?
    @Published var selectedSlideIndex: Int = 0
    @Published var searchText: String = "pulsed field ablation AND atrial fibrillation"
    @Published var yearFrom: Int = 2024
    @Published var enabledFilters: Set<String> = []
    @Published var tasks: [ProcessingTask] = SampleData.processingTasks
    @Published var progress: Double = 0.0
    @Published var toastMessage: String?
    @Published var isBusy: Bool = false

    // MARK: - Real data (source of truth)
    @Published private var drafts: [ArticleDraft] = []
    @Published var selectedForExport: Set<String> = []
    @Published var topicTreeNodes: [TopicNode] = []
    @Published var impactFactorByJournal: [String: String] = [:]
    @Published var apiKey: String = ""
    @Published var pptTemplateURL: URL?

    let customStudyTerms = ["综述", "社论", "动物实验", "土豆模型"]

    // MARK: - Static config (navigation & previews, not result data)
    let quickActions = SampleData.quickActions
    let importMappings = SampleData.importMappings
    let exportMappings = SampleData.exportMappings
    let pptMappings = SampleData.pptMappings
    let projects = SampleData.projects
    let searchFilters = SampleData.searchFilters

    // MARK: - Services
    private let store: LibraryStore
    private let pubmed: PubMedFetching

    init(pubmed: PubMedFetching = PubMedService(), store: LibraryStore = LibraryStore()) {
        self.pubmed = pubmed
        self.store = store
        let snapshot = store.load()
        self.impactFactorByJournal = snapshot.impactFactorByJournal
        // Empty by default: only restore genuinely persisted user data, never seed demo rows.
        if let seeded = snapshot.projects.first(where: { !$0.articles.isEmpty }) {
            self.drafts = seeded.articles
        } else {
            self.drafts = []
        }
        self.selectedArticleID = articles.first?.id
    }

    // MARK: - Data state
    var articleCount: Int { drafts.count }
    var hasData: Bool { !drafts.isEmpty }
    var pptTemplateName: String { pptTemplateURL?.lastPathComponent ?? "未选择模板" }

    /// 载入内置示例数据（按需，不再默认污染界面）。
    func loadSampleData() {
        drafts = SampleData.articles.map(Self.draft(from:))
        topicTreeNodes = SampleData.topicTree
        if impactFactorByJournal.isEmpty {
            impactFactorByJournal = Self.sampleImpactFactors
        }
        selectedForExport = []
        selectedArticleID = articles.first?.id
        persist()
        showToast("已载入示例数据：\(drafts.count) 篇")
    }

    /// 清空当前文献库，回到空状态。
    func clearAll() {
        drafts = []
        selectedForExport = []
        selectedArticleID = nil
        persist()
        showToast("已清空文献库")
    }

    // MARK: - Derived display
    var topicTree: [TopicNode] { topicTreeNodes }

    var articles: [Article] {
        drafts.enumerated().map { index, draft in
            let id = (draft.pmid?.isEmpty == false ? draft.pmid! : "row-\(index)")
            return Self.display(draft, id: id)
        }
    }

    // MARK: - Derived dashboard data (live, never hardcoded)
    var translatedCount: Int { drafts.filter { !$0.abstractCN.isEmpty || !$0.titleCN.isEmpty }.count }
    var pendingReviewCount: Int { drafts.filter { $0.confidence < 0.7 }.count }

    var stats: [StatItem] {
        let total = drafts.count
        let pct = total == 0 ? 0 : Int((Double(translatedCount) / Double(total) * 100).rounded())
        return [
            StatItem(title: "文献总量", value: "\(total)", detail: total == 0 ? "尚无数据" : "当前项目文献", symbol: "chart.bar.fill"),
            StatItem(title: "已翻译", value: "\(translatedCount)", detail: "\(pct)% 已完成", symbol: "character.book.closed.fill"),
            StatItem(title: "待复核", value: "\(pendingReviewCount)", detail: pendingReviewCount == 0 ? "无待复核" : "建议优先处理", symbol: "clock.badge.exclamationmark.fill"),
            StatItem(title: "IF 条目", value: "\(impactFactorByJournal.count)", detail: impactFactorByJournal.isEmpty ? "未导入 IF" : "已导入数据集", symbol: "square.on.square.intersection.dashed")
        ]
    }

    var alerts: [AlertItem] {
        var items: [AlertItem] = []
        if pendingReviewCount > 0 { items.append(AlertItem(title: "\(pendingReviewCount) 条低置信度结果待复核")) }
        if !impactFactorByJournal.isEmpty { items.append(AlertItem(title: "IF 数据集已导入 \(impactFactorByJournal.count) 条")) }
        if pptTemplateURL != nil { items.append(AlertItem(title: "onepage PPT 模板已配置")) }
        if drafts.isEmpty {
            items.append(AlertItem(title: "尚无数据：请导入 Excel/CSV 或从 PubMed 检索"))
        } else if items.isEmpty {
            items.append(AlertItem(title: "数据就绪，可开始 AI 加工与导出"))
        }
        return items
    }

    var queue: [QueueItem] {
        drafts.prefix(6).map { draft in
            let title = draft.titleEN.isEmpty ? draft.titleCN : draft.titleEN
            return QueueItem(title: title.isEmpty ? "(无标题)" : title, status: draft.abstractCN.isEmpty ? .waiting : .done)
        }
    }

    // MARK: - Transparent PubMed query (derived from user input)
    var searchTerms: [String] {
        searchText
            .components(separatedBy: " AND ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var displayedQuery: String {
        PubMedQueryBuilder.buildQuery(keywords: [], requiredTerms: searchTerms, yearRange: yearFrom...3000)
    }

    // MARK: - Export selection
    var articlesToExport: [ArticleDraft] {
        guard !selectedForExport.isEmpty else { return drafts }
        return drafts.enumerated()
            .filter { index, draft in selectedForExport.contains(draft.pmid?.isEmpty == false ? draft.pmid! : "row-\(index)") }
            .map { $0.element }
    }

    func isSelectedForExport(_ article: Article) -> Bool { selectedForExport.contains(article.id) }

    func toggleExportSelection(_ article: Article) {
        if selectedForExport.contains(article.id) { selectedForExport.remove(article.id) }
        else { selectedForExport.insert(article.id) }
    }

    var activeArticle: Article {
        selectedArticle ?? articles.first ?? Self.placeholderArticle
    }

    var selectedArticle: Article? {
        articles.first { $0.id == selectedArticleID } ?? articles.first
    }

    var pageTitle: String { selectedSection?.title ?? "MedEditAI" }

    // MARK: - Navigation actions
    func navigate(to section: AppSection) { selectedSection = section }

    func chooseProject(_ project: Project) {
        selectedProject = project
        showToast("已切换项目：\(project.name)")
    }

    func chooseArticle(_ article: Article) { selectedArticleID = article.id }

    func chooseSlide(index: Int) {
        selectedSlideIndex = index
        if articles.indices.contains(index) {
            selectedArticleID = articles[index].id
        }
    }

    func toggleTask(_ task: ProcessingTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isEnabled.toggle()
        showToast("\(tasks[index].title)已\(tasks[index].isEnabled ? "启用" : "关闭")")
    }

    func toggleFilter(_ filter: String) {
        if enabledFilters.contains(filter) { enabledFilters.remove(filter) } else { enabledFilters.insert(filter) }
    }

    // MARK: - Real: PubMed search + enrichment
    func runSearch() async {
        guard !isBusy else { return }
        isBusy = true
        progress = 0
        showToast("正在检索 PubMed…")
        defer { isBusy = false }
        do {
            let ids = try await pubmed.search(query: displayedQuery, maxResults: 25)
            guard !ids.isEmpty else { showToast("未找到结果"); return }
            let records = try await pubmed.fetch(pmids: ids)
            let enriched = await enrichmentService().enrichBatch(records: records) { [weak self] progress in
                Task { @MainActor in self?.progress = progress.fraction }
            }
            drafts = enriched
            selectedForExport = []
            selectedArticleID = articles.first?.id
            persist()
            showToast("检索完成：入库 \(enriched.count) 篇")
        } catch {
            showToast("检索失败：\(error.localizedDescription)")
        }
    }

    func runEnrichment() async {
        guard !isBusy, !drafts.isEmpty else { return }
        isBusy = true
        progress = 0
        defer { isBusy = false }
        let records = drafts.map(Self.record(from:))
        let enriched = await enrichmentService().enrichBatch(records: records) { [weak self] progress in
            Task { @MainActor in self?.progress = progress.fraction }
        }
        drafts = enriched
        selectedArticleID = articles.first?.id
        persist()
        showToast("批处理完成：\(enriched.count) 篇已更新 AI 结果")
    }

    // MARK: - Real: import / export
    func importDocument() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let imported = try DocumentService.importArticles(from: url)
            guard !imported.isEmpty else { showToast("未从文件解析到文献"); return }
            replaceDrafts(imported, toast: "导入成功：\(imported.count) 篇")
        } catch {
            showToast("导入失败：\(error.localizedDescription)")
        }
    }

    /// 用新的文献集合替换当前库（导入/检索共用；可单元测试）。
    func replaceDrafts(_ newDrafts: [ArticleDraft], toast: String? = nil) {
        drafts = newDrafts
        selectedForExport = []
        selectedArticleID = articles.first?.id
        persist()
        if let toast { showToast(toast) }
    }

    func importImpactFactors() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let table = try DocumentService.importImpactFactors(from: url)
            setImpactFactors(table, toast: "已导入 IF 数据：\(table.count) 条")
        } catch {
            showToast("IF 导入失败：\(error.localizedDescription)")
        }
    }

    /// 设置 IF 表并回填到现有文献（可单元测试）。
    func setImpactFactors(_ table: [String: String], toast: String? = nil) {
        impactFactorByJournal = table
        reapplyImpactFactors()
        persist()
        if let toast { showToast(toast) }
    }

    func importClassificationDictionary() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let rows: [[String]]
            if url.pathExtension.lowercased() == "xlsx" {
                rows = try XLSXReader.read(url: url)
            } else {
                rows = CSVEngine.parse(try String(contentsOf: url, encoding: .utf8))
            }
            let count = applyClassification(rows: rows)
            showToast("已导入分类字典：\(count) 条路径")
        } catch {
            showToast("分类字典导入失败：\(error.localizedDescription)")
        }
    }

    /// 从行数据构建四级主题树并应用（可单元测试）。返回叶子路径数。
    @discardableResult
    func applyClassification(rows: [[String]]) -> Int {
        let scheme = ClassificationEngine.buildTree(from: rows)
        topicTreeNodes = Self.nodes(from: scheme)
        return ClassificationEngine.flattenPaths(in: scheme).count
    }

    func chooseTemplate() {
        guard let url = openPanel(extensions: ["pptx"]) else { return }
        pptTemplateURL = url
        showToast("已选择 PPT 模板：\(url.lastPathComponent)")
    }

    func exportExcel() {
        guard !drafts.isEmpty else { showToast("暂无可导出的文献"); return }
        guard let url = savePanel(suggestedName: "MedEditAI-交付.xlsx") else { return }
        do {
            try DocumentService.exportExcel(articles: articlesToExport, template: Self.deliveryTemplate, to: url)
            showToast("已导出 Excel 交付表：\(articlesToExport.count) 篇")
        } catch {
            showToast("导出失败：\(error.localizedDescription)")
        }
    }

    func exportPPTX() {
        guard !drafts.isEmpty else { showToast("暂无可导出的文献"); return }
        guard let template = pptTemplateURL ?? openPanel(extensions: ["pptx"]) else {
            showToast("请先选择 onepage PPT 模板")
            return
        }
        pptTemplateURL = template
        guard let output = savePanel(suggestedName: "MedEditAI-onepage.pptx") else { return }
        do {
            try DocumentService.exportPPTX(articles: articlesToExport, templateURL: template, to: output)
            showToast("已导出 onepage PPT：\(articlesToExport.count) 页")
        } catch {
            showToast("导出失败：\(error.localizedDescription)")
        }
    }

    // MARK: - Toast
    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.toastMessage == message { self.toastMessage = nil }
        }
    }

    // MARK: - Helpers
    private func enrichmentService() -> EnrichmentService {
        let provider: LLMProviding = apiKey.isEmpty ? LocalDeterministicLLM() : OpenAICompatibleLLM(apiKey: apiKey)
        return EnrichmentService(
            llm: provider,
            topicScheme: Self.scheme(from: topicTreeNodes),
            customStudyTerms: customStudyTerms,
            impactFactorByJournal: impactFactorByJournal
        )
    }

    private func reapplyImpactFactors() {
        drafts = drafts.map { draft in
            var updated = draft
            let key = draft.journal.lowercased().replacingOccurrences(of: " ", with: "")
            if let value = impactFactorByJournal[key] { updated.impactFactor = value }
            return updated
        }
    }

    private func persist() {
        try? store.save(
            LibrarySnapshot(
                projects: [StoredProject(name: selectedProject.name, colorHex: "#0E9F9F", articles: drafts)],
                customStudyTerms: customStudyTerms,
                impactFactorByJournal: impactFactorByJournal
            )
        )
    }

    private func openPanel(extensions: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = extensions.compactMap { UTType(filenameExtension: $0) }
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func savePanel(suggestedName: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if let ext = suggestedName.split(separator: ".").last, let type = UTType(filenameExtension: String(ext)) {
            panel.allowedContentTypes = [type]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Static conversions
    static let deliveryTemplate = ExportTemplate(
        name: "PFA 交付 Excel",
        columns: ["主题", "序号", "标题", "摘要/内容简介详情链接", "作者", "发表日期", "研究类型", "期刊", "2025年IF", "PMID", "原文链接"],
        hyperlinkFields: ["原文链接", "摘要/内容简介详情链接"]
    )

    /// 空状态占位文章（避免在无数据时显示示例内容）。
    static let placeholderArticle = Article(
        id: "placeholder", topic: "暂无主题", titleEN: "暂无文献", titleCN: "请导入 Excel/CSV 或从 PubMed 检索",
        abstractEN: "", abstractCN: "当前文献库为空。你可以导入 Excel/CSV、从 PubMed 检索，或载入示例数据来开始。",
        citation: "", authors: "—", date: "—", studyType: "—", journal: "—",
        impactFactor: "", quartile: "", pmid: "", url: "", confidence: .medium, product: "—", evidence: "—", note: ""
    )

    /// 从内置示例文献推导的 IF 映射表（仅在用户未导入自有数据时用于示例）。
    static var sampleImpactFactors: [String: String] {
        var table: [String: String] = [:]
        for article in SampleData.articles where !article.impactFactor.isEmpty {
            let key = article.journal.lowercased().replacingOccurrences(of: " ", with: "")
            table[key] = article.impactFactor
        }
        return table
    }

    static func draft(from article: Article) -> ArticleDraft {
        ArticleDraft(
            topic: article.topic,
            titleEN: article.titleEN,
            titleCN: article.titleCN,
            abstractEN: article.abstractEN,
            abstractCN: article.abstractCN,
            citation: article.citation,
            authors: article.authors,
            date: article.date,
            studyType: article.studyType,
            journal: article.journal,
            impactFactor: article.impactFactor.isEmpty ? nil : article.impactFactor,
            quartile: article.quartile.isEmpty ? nil : article.quartile,
            pmid: article.pmid.isEmpty ? nil : article.pmid,
            url: article.url.isEmpty ? nil : article.url,
            confidence: article.confidence == .high ? 0.95 : article.confidence == .medium ? 0.78 : 0.6,
            product: article.product,
            evidence: article.evidence,
            note: article.note
        )
    }

    static func record(from draft: ArticleDraft) -> PubMedRecord {
        PubMedRecord(
            pmid: draft.pmid ?? "",
            title: draft.titleEN,
            abstract: draft.abstractEN,
            authors: draft.authors.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            journal: draft.journal,
            pubDate: draft.date,
            doi: nil,
            keywords: [],
            meshTerms: [],
            references: []
        )
    }

    static func display(_ draft: ArticleDraft, id: String) -> Article {
        Article(
            id: id,
            topic: draft.topic,
            titleEN: draft.titleEN,
            titleCN: draft.titleCN,
            abstractEN: draft.abstractEN,
            abstractCN: draft.abstractCN,
            citation: draft.citation,
            authors: draft.authors,
            date: draft.date,
            studyType: draft.studyType,
            journal: draft.journal,
            impactFactor: draft.impactFactor ?? "",
            quartile: draft.quartile ?? "",
            pmid: draft.pmid ?? "",
            url: draft.url ?? "",
            confidence: level(draft.confidence),
            product: draft.product,
            evidence: draft.evidence,
            note: draft.note
        )
    }

    static func level(_ confidence: Double) -> ConfidenceLevel {
        confidence >= 0.85 ? .high : confidence >= 0.7 ? .medium : .low
    }

    static func scheme(from nodes: [TopicNode]) -> ClassificationScheme {
        ClassificationScheme(name: "主题分类", type: .topic, isHierarchical: true, items: nodes.map(classificationNode(from:)))
    }

    static func classificationNode(from node: TopicNode) -> ClassificationNode {
        ClassificationNode(title: node.title, level: node.level, children: node.children.map(classificationNode(from:)))
    }

    static func nodes(from scheme: ClassificationScheme) -> [TopicNode] {
        scheme.items.map(topicNode(from:))
    }

    static func topicNode(from node: ClassificationNode) -> TopicNode {
        TopicNode(title: node.title, level: node.level, count: node.children.isEmpty ? 0 : nil, children: node.children.map(topicNode(from:)))
    }
}
