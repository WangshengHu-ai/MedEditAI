import Foundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    // MARK: - Navigation & selection
    @Published var selectedSection: AppSection? = .dashboard
    @Published var selectedArticleID: String?
    @Published var selectedSlideIndex: Int = 0
    @Published var searchText: String = ""
    @Published var yearFrom: Int = 2024
    @Published var sortOrder: PubMedSort = .bestMatch
    @Published var enabledFilters: Set<String> = []
    @Published var tasks: [ProcessingTask] = SampleData.processingTasks
    @Published var progress: Double = 0.0
    @Published var toastMessage: String?
    @Published var isBusy: Bool = false

    // MARK: - Search pagination
    @Published var totalHits: Int = 0
    @Published var currentPage: Int = 0        // 0-indexed
    let pageSize = 25

    // MARK: - Projects (source of truth)
    @Published private var storedProjects: [StoredProject]
    @Published var selectedProjectID: UUID

    // MARK: - Per-project working state
    @Published var selectedForExport: Set<String> = []
    @Published var topicTreeNodes: [TopicNode] = []
    @Published var impactFactorByJournal: [String: String] = [:]
    @Published var apiKey: String = ""
    @Published var pptTemplateURL: URL?
    @Published var promptTemplates: PromptTemplates = .default

    // MARK: - Import mapping confirmation
    @Published var pendingImport: ImportAnalysis?
    let canonicalFieldOptions = ImportAnalyzer.canonicalFields

    // MARK: - Topic filter (classification tree)
    @Published var selectedTopic: String?

    let customStudyTerms = ["综述", "社论", "动物实验"]

    // MARK: - Static config (navigation & previews, not result data)
    let quickActions = SampleData.quickActions
    let importMappings = SampleData.importMappings
    let exportMappings = SampleData.exportMappings
    let pptMappings = SampleData.pptMappings
    let searchFilters = SampleData.searchFilters
    let sortOptions = PubMedSort.allCases

    // MARK: - Services
    private let store: LibraryStore
    private let pubmed: PubMedFetching

    init(pubmed: PubMedFetching = PubMedService(), store: LibraryStore = LibraryStore()) {
        self.pubmed = pubmed
        self.store = store
        let snapshot = store.load()
        self.impactFactorByJournal = snapshot.impactFactorByJournal
        self.promptTemplates = snapshot.promptTemplates ?? .default
        if snapshot.projects.isEmpty {
            let defaultProject = StoredProject(name: "我的文献库", colorHex: "#0E9F9F", articles: [])
            self.storedProjects = [defaultProject]
            self.selectedProjectID = defaultProject.id
        } else {
            self.storedProjects = snapshot.projects
            self.selectedProjectID = snapshot.projects[0].id
        }
        self.selectedArticleID = articles.first?.id
    }

    /// 应用启动工厂：UI 测试传入 `-uitest-reset` 时使用一次性临时存储，保证每次启动干净、隔离。
    static func makeForLaunch() -> AppViewModel {
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("uitest-\(UUID().uuidString).json")
            return AppViewModel(store: LibraryStore(fileURL: url))
        }
        return AppViewModel()
    }

    // MARK: - Active project data (single source of truth)
    private var activeProjectIndex: Int? {
        storedProjects.firstIndex(where: { $0.id == selectedProjectID })
    }

    private var drafts: [ArticleDraft] {
        get { activeProjectIndex.map { storedProjects[$0].articles } ?? [] }
        set {
            if let index = activeProjectIndex { storedProjects[index].articles = newValue }
        }
    }

    var projects: [Project] {
        storedProjects.map { Project(id: $0.id, name: $0.name, color: Color(hex: $0.colorHex)) }
    }

    var selectedProject: Project {
        projects.first(where: { $0.id == selectedProjectID }) ?? projects.first ?? Project(name: "文献库", color: AppTheme.accent)
    }

    private func draftID(_ draft: ArticleDraft, index: Int) -> String {
        (draft.pmid?.isEmpty == false) ? draft.pmid! : "row-\(index)"
    }

    // MARK: - Data state
    var articleCount: Int { drafts.count }
    var hasData: Bool { !drafts.isEmpty }
    var pptTemplateName: String { pptTemplateURL?.lastPathComponent ?? "未选择模板" }
    /// AI 加工目标数：有勾选则为勾选数，否则为全部。
    var enrichmentTargetCount: Int { selectedForExport.isEmpty ? drafts.count : selectedForExport.count }

    /// 载入内置示例数据（仅当前会话预览，不持久化，避免重启后“假数据”残留）。
    func loadSampleData() {
        drafts = SampleData.articles.map(Self.draft(from:))
        topicTreeNodes = SampleData.topicTree
        if impactFactorByJournal.isEmpty {
            impactFactorByJournal = Self.sampleImpactFactors
        }
        selectedForExport = []
        selectedTopic = nil
        selectedArticleID = articles.first?.id
        showToast("已载入示例数据（预览，不保存）：\(drafts.count) 篇")
    }

    /// 清空当前文献库，回到空状态。
    func clearAll() {
        drafts = []
        selectedForExport = []
        selectedTopic = nil
        selectedArticleID = nil
        resetSearchPaging()
        persist()
        showToast("已清空文献库")
    }

    // MARK: - Project management
    func chooseProject(_ project: Project) {
        guard project.id != selectedProjectID else { return }
        selectedProjectID = project.id
        selectedForExport = []
        selectedTopic = nil
        selectedArticleID = articles.first?.id
        resetSearchPaging()
        selectedSection = .dashboard    // 切换项目后回到工作台，给出明确反馈
        showToast("已切换项目：\(project.name)")
    }

    @discardableResult
    func addProject(name: String, colorHex: String = "#0E9F9F") -> UUID {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "未命名项目" : trimmed
        let project = StoredProject(name: finalName, colorHex: colorHex, articles: [])
        storedProjects.append(project)
        selectedProjectID = project.id
        selectedForExport = []
        selectedArticleID = nil
        resetSearchPaging()
        persist()
        showToast("已创建项目：\(finalName)")
        return project.id
    }

    func renameProject(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = storedProjects.firstIndex(where: { $0.id == id }) else { return }
        storedProjects[index].name = trimmed
        persist()
        showToast("已重命名为：\(trimmed)")
    }

    func deleteProject(id: UUID) {
        guard storedProjects.count > 1, let index = storedProjects.firstIndex(where: { $0.id == id }) else {
            showToast("至少保留一个项目")
            return
        }
        let removedName = storedProjects[index].name
        storedProjects.remove(at: index)
        if selectedProjectID == id {
            selectedProjectID = storedProjects[0].id
            selectedForExport = []
            selectedArticleID = articles.first?.id
            resetSearchPaging()
        }
        persist()
        showToast("已删除项目：\(removedName)")
    }

    // MARK: - Derived display
    var topicTree: [TopicNode] { topicTreeNodes }

    var articles: [Article] {
        drafts.enumerated().map { index, draft in
            let id = (draft.pmid?.isEmpty == false ? draft.pmid! : "row-\(index)")
            return Self.display(draft, id: id)
        }
    }

    /// 按当前选中的主题过滤后的文献列表（分类树点击驱动）。
    var filteredArticles: [Article] {
        guard let topic = selectedTopic, !topic.isEmpty else { return articles }
        return articles.filter { $0.topic == topic }
    }

    /// 点击分类树叶子节点：选中则过滤，再次点击同一个则取消过滤。
    func selectTopic(_ topic: String?) {
        if let topic, selectedTopic != topic {
            selectedTopic = topic
        } else {
            selectedTopic = nil
        }
        selectedArticleID = filteredArticles.first?.id
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

    // MARK: - Search pagination state
    var totalPages: Int {
        guard totalHits > 0 else { return 0 }
        return (totalHits + pageSize - 1) / pageSize
    }
    var canGoNextPage: Bool { currentPage + 1 < totalPages }
    var canGoPrevPage: Bool { currentPage > 0 }
    var resultRangeText: String {
        guard totalHits > 0, !drafts.isEmpty else { return "" }
        let start = currentPage * pageSize + 1
        let end = min(start + drafts.count - 1, totalHits)
        return "第 \(start)–\(end) 条 / 共 \(totalHits) 条"
    }

    private func resetSearchPaging() {
        totalHits = 0
        currentPage = 0
    }

    // MARK: - Real: PubMed search (paged) + offline auto-recognition
    func runSearch() async { await performSearch(page: 0) }

    func nextPage() async {
        guard canGoNextPage else { return }
        await performSearch(page: currentPage + 1)
    }

    func prevPage() async {
        guard canGoPrevPage else { return }
        await performSearch(page: currentPage - 1)
    }

    func changeSort(_ sort: PubMedSort) async {
        guard sort != sortOrder else { return }
        sortOrder = sort
        if !searchTerms.isEmpty { await performSearch(page: 0) }
    }

    private func performSearch(page: Int) async {
        guard !isBusy, !searchTerms.isEmpty else { return }
        isBusy = true
        progress = 0
        showToast("正在检索 PubMed…")
        defer { isBusy = false }
        do {
            let result = try await pubmed.search(query: displayedQuery, sort: sortOrder, retstart: page * pageSize, retmax: pageSize)
            totalHits = result.total
            currentPage = page
            guard !result.ids.isEmpty else {
                replaceDrafts([])
                showToast("未找到结果")
                return
            }
            let records = try await pubmed.fetch(pmids: result.ids)
            let recognized = records.map(autoRecognize(record:))
            replaceDrafts(recognized)
            showToast("检索完成：第 \(page + 1)/\(max(totalPages, 1)) 页，共 \(totalHits) 条")
        } catch {
            showToast("检索失败：\(error.localizedDescription)")
        }
    }

    /// 离线确定性“自动识别”：入库即填充研究设计/主题/产品/IF（不联网、不翻译）。
    func autoRecognize(record: PubMedRecord) -> ArticleDraft {
        let context = ArticleProcessingContext(
            customStudyTerms: customStudyTerms,
            topicScheme: Self.scheme(from: topicTreeNodes),
            impactFactorByJournal: impactFactorByJournal
        )
        var draft = ArticleProcessor.enrich(record: record, context: context)
        if (draft.url ?? "").isEmpty, let doi = record.doi, !doi.isEmpty {
            draft.url = "https://doi.org/\(doi)"
        }
        return draft
    }

    /// 对已导入的文献补齐可离线识别的字段（仅填空，不覆盖用户已有内容）。
    func autoRecognize(draft: ArticleDraft) -> ArticleDraft {
        var updated = draft
        let raw = [draft.titleEN, draft.abstractEN, draft.titleCN, draft.abstractCN].joined(separator: " ")
        if updated.studyType.trimmingCharacters(in: .whitespaces).isEmpty {
            updated.studyType = ClassificationEngine.classifyStudyDesign(in: raw, customTerms: customStudyTerms).design
        }
        if updated.product.trimmingCharacters(in: .whitespaces).isEmpty {
            updated.product = ArticleProcessor.inferProduct(from: raw)
        }
        if (updated.impactFactor ?? "").isEmpty {
            let key = draft.journal.lowercased().replacingOccurrences(of: " ", with: "")
            updated.impactFactor = impactFactorByJournal[key]
        }
        if updated.topic.trimmingCharacters(in: .whitespaces).isEmpty || updated.topic == "未分类" {
            let inferred = ArticleProcessor.inferTopic(from: draft.titleEN + " " + draft.abstractEN, scheme: Self.scheme(from: topicTreeNodes))
            if inferred != "未分类" { updated.topic = inferred }
        }
        return updated
    }

    // MARK: - AI 加工：批量处理“选中”的文献（未选则全部），结果就地写回卡片
    func runEnrichment() async {
        guard !isBusy, !drafts.isEmpty else { return }
        guard !apiKey.isEmpty else {
            showToast("请先在设置中配置云端 LLM API Key")
            return
        }
        isBusy = true
        progress = 0
        defer { isBusy = false }

        let targetIDs = selectedForExport.isEmpty ? Set(articles.map(\.id)) : selectedForExport
        var working = drafts
        let total = working.indices.filter { targetIDs.contains(draftID(working[$0], index: $0)) }.count
        guard total > 0 else { showToast("请选择要加工的文献"); return }
        showToast("使用云端 LLM 加工中…")

        let service = enrichmentService()
        var processed = 0
        for index in working.indices {
            guard targetIDs.contains(draftID(working[index], index: index)) else { continue }
            let record = Self.record(from: working[index])
            let enriched = await service.enrich(record: record)
            working[index] = Self.merged(original: working[index], enriched: enriched)
            processed += 1
            progress = Double(processed) / Double(total)
        }
        drafts = working
        selectedArticleID = articles.first(where: { targetIDs.contains($0.id) })?.id ?? selectedArticleID
        persist()
        showToast("批处理完成：\(processed) 篇已更新 AI 结果")
    }

    // MARK: - 待复核：手动修改并保存
    func saveArticleEdits(
        id: String,
        topic: String,
        titleCN: String,
        abstractCN: String,
        studyType: String,
        product: String,
        note: String,
        markReviewed: Bool
    ) {
        var working = drafts
        for index in working.indices where draftID(working[index], index: index) == id {
            working[index].topic = topic
            working[index].titleCN = titleCN
            working[index].abstractCN = abstractCN
            working[index].studyType = studyType
            working[index].product = product
            working[index].note = note
            if markReviewed { working[index].confidence = max(working[index].confidence, 0.95) }
            drafts = working
            selectedArticleID = id
            persist()
            showToast(markReviewed ? "已保存并标记为已复核" : "已保存修改")
            return
        }
        showToast("未找到要保存的文献")
    }

    // MARK: - Real: import / export
    func importDocument() {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return }
        do {
            let rows = try DocumentService.readRows(from: url)
            let analysis = ImportAnalyzer.analyze(rows: rows)
            guard analysis.kind != .unknown else {
                showToast("无法识别文件结构：需包含标题列或四级分类列")
                return
            }
            // 分析完成 → 弹出确认界面，用户确认/调整映射
            pendingImport = analysis
        } catch {
            showToast("导入失败：\(error.localizedDescription)")
        }
    }

    /// 用户确认（可能已调整）文献列映射后，应用生成草稿。
    func confirmArticleImport(proposals: [ColumnProposal]) {
        guard let analysis = pendingImport else { return }
        let imported = ImportAnalyzer.articles(from: analysis, proposals: proposals)
        pendingImport = nil
        guard !imported.isEmpty else {
            showToast("按当前映射未解析到文献（需至少映射“标题（英文）”列）")
            return
        }
        let recognized = imported.map(autoRecognize(draft:))
        replaceDrafts(recognized, toast: "导入成功：\(recognized.count) 篇（映射已确认）")
    }

    /// 用户确认分类字典导入。
    func confirmClassificationImport() {
        guard let analysis = pendingImport, analysis.kind == .classification else { return }
        let count = applyClassification(rows: Array(analysis.rows[analysis.headerIndex...]))
        pendingImport = nil
        showToast("已导入分类字典：\(count) 条路径")
    }

    func cancelImport() { pendingImport = nil }

    /// 用新的文献集合替换当前库（导入/检索共用；可单元测试）。
    func replaceDrafts(_ newDrafts: [ArticleDraft], toast: String? = nil) {
        drafts = newDrafts
        selectedForExport = []
        selectedTopic = nil
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

    // MARK: - AI Prompt 模板（查看/自定义）
    func savePromptTemplates(_ templates: PromptTemplates) {
        promptTemplates = templates
        persist()
        showToast("已保存 AI Prompt 模板")
    }

    func resetPromptTemplates() {
        promptTemplates = .default
        persist()
        showToast("已恢复默认 Prompt")
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
#if DEBUG
    var sessionForTesting: URLSession?
#endif

    private func enrichmentService() -> EnrichmentService {
        let provider = OpenAICompatibleLLM(
            apiKey: apiKey, 
            session: {
#if DEBUG
                if let s = sessionForTesting { return s }
#endif
                return .shared
            }(),
            templates: promptTemplates
        )
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
                projects: storedProjects,
                customStudyTerms: customStudyTerms,
                impactFactorByJournal: impactFactorByJournal,
                promptTemplates: promptTemplates
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

    /// 将 AI 加工结果合并回原始文献（只覆盖有意义的新结果，保留原始元数据）。
    static func merged(original: ArticleDraft, enriched: ArticleDraft) -> ArticleDraft {
        var result = original
        if !enriched.titleCN.isEmpty { result.titleCN = enriched.titleCN }
        if !enriched.abstractCN.isEmpty { result.abstractCN = enriched.abstractCN }
        if !enriched.topic.isEmpty, enriched.topic != "未分类" { result.topic = enriched.topic }
        if !enriched.studyType.isEmpty { result.studyType = enriched.studyType }
        if !enriched.product.isEmpty, enriched.product != "未识别" { result.product = enriched.product }
        if let factor = enriched.impactFactor, !factor.isEmpty { result.impactFactor = factor }
        if !enriched.citation.isEmpty { result.citation = enriched.citation }
        if !enriched.evidence.isEmpty { result.evidence = enriched.evidence }
        result.confidence = enriched.confidence
        result.note = enriched.note
        if let kw = enriched.keywords, !kw.isEmpty { result.keywords = kw }
        return result
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
            note: article.note,
            keywords: article.keywords.isEmpty ? nil : article.keywords
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
            keywords: (draft.keywords ?? "").split(whereSeparator: { $0 == "," || $0 == "；" || $0 == ";" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
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
            note: draft.note,
            keywords: draft.keywords ?? ""
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
