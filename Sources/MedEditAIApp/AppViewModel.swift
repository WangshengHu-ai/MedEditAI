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
    /// 起始年份；nil 表示用户未指定，不限制年份下限。
    @Published var yearFrom: Int? = nil
    @Published var sortOrder: PubMedSort = .bestMatch
    @Published var tasks: [ProcessingTask] = SampleData.processingTasks
    @Published var progress: Double = 0.0
    @Published var toastMessage: String?
    @Published var isBusy: Bool = false

    // MARK: - Search pagination
    @Published var totalHits: Int = 0
    @Published var currentPage: Int = 0        // 0-indexed
    @Published var pageSize: Int = 25
    let pageSizeOptions: [Int] = [10, 25, 50, 100, 200, 500, 1000]

    // MARK: - Projects (source of truth)
    @Published private var storedProjects: [StoredProject]
    @Published var selectedProjectID: UUID

    // MARK: - Per-project working state
    @Published var selectedForExport: Set<String> = []
    @Published var topicTreeNodes: [TopicNode] = []
    @Published var impactFactorByJournal: [String: String] = [:]
    @Published var apiKey: String = ""
    @Published var ncbiApiKey: String = ""
    /// 云端 LLM 接口地址（OpenAI 兼容）。默认指向智谱 BigModel；可在设置中改为任意 OpenAI 兼容服务。
    @Published var llmEndpoint: String = AppViewModel.defaultLLMEndpoint
    /// 云端 LLM 模型名。默认 glm-4-flash；可在设置中改为 gpt-4o-mini 等。
    @Published var llmModel: String = AppViewModel.defaultLLMModel
    @Published var pptTemplateURL: URL?
    @Published var pptVisualTemplate: PPTVisualTemplate = .init()
    @Published var promptTemplates: PromptTemplates = .default
    @Published var exportColumns: [ExportColumnConfig] = ProjectConfig.defaultExportColumns
    @Published var pptPlaceholderMappings: [PPTPlaceholderMapping] = ProjectConfig.defaultPPTPlaceholders
    @Published var customTasks: [CustomProcessingTask] = []
    @Published var defaultProjectConfig: ProjectConfig = .default
    @Published var enrichmentQueue: [QueueItem] = []
    /// 上一次构建 `enrichmentQueue` 时对应的文献 id 序列；用于判断缓存的队列是否仍与当前项目的文献集合一致（
    /// 否则切换项目/重新导入搜索后会错误地复用上一批的题目与状态）。
    private var enrichmentQueueDraftIDs: [String] = []
    private var enrichmentQueueProjectID: UUID?
    @Published var isEnrichmentPaused: Bool = false
    @Published var enrichmentCompleted: Bool = false

    // MARK: - Import mapping confirmation
    @Published var pendingImport: ImportAnalysis?
    let canonicalFieldOptions = ImportAnalyzer.canonicalFields
    let classificationFieldOptions = ImportAnalyzer.classificationFieldOptions

    // MARK: - Topic filter (classification tree)
    @Published var selectedTopic: String?

    /// 用户自定义研究类型词条；为空时 AI 加工会根据标题/摘要自动推断，仍无法判断则留空。
    @Published var customStudyTerms: [String] = []

    /// 文献库页是否只显示待人工复核的低置信度结果。
    @Published var showLowConfidenceOnly: Bool = false

    // MARK: - Static config (navigation & previews, not result data)
    let quickActions = SampleData.quickActions
    let importMappings = SampleData.importMappings
    let exportMappings = SampleData.exportMappings
    let pptMappings = SampleData.pptMappings
    let sortOptions = PubMedSort.allCases

    /// 云端 LLM 默认配置：默认指向智谱 BigModel 的 OpenAI 兼容接口与免费的 glm-4-flash 模型，
    /// 用户只需在设置里填入 API Key 即可开箱即用；也可改为任意其他 OpenAI 兼容服务与模型。
    static let defaultLLMEndpoint = "https://open.bigmodel.cn/api/paas/v4/chat/completions"
    static let defaultLLMModel = "glm-4-flash"

    // MARK: - Services
    private let store: LibraryStore
    private let pubmedProvider: PubMedFetching?
    private let llmProvider: LLMProviding?

    private var pubmed: PubMedFetching {
        pubmedProvider ?? PubMedService(apiKey: ncbiApiKey.isEmpty ? nil : ncbiApiKey)
    }

    init(pubmed: PubMedFetching? = nil, llmProvider: LLMProviding? = nil, store: LibraryStore = LibraryStore()) {
        self.pubmedProvider = pubmed
        self.llmProvider = llmProvider
        self.store = store
        let snapshot = store.load()
        let resolvedDefaultConfig = snapshot.defaultProjectConfig ?? .default
        self.defaultProjectConfig = resolvedDefaultConfig
        self.impactFactorByJournal = snapshot.impactFactorByJournal
        self.promptTemplates = snapshot.promptTemplates ?? .default
        self.customStudyTerms = snapshot.customStudyTerms
        self.topicTreeNodes = snapshot.topicScheme.map(Self.nodes(from:)) ?? []
        self.apiKey = snapshot.apiKey ?? ""
        self.ncbiApiKey = snapshot.ncbiApiKey ?? ""
        self.llmEndpoint = snapshot.llmEndpoint?.isEmpty == false ? snapshot.llmEndpoint! : Self.defaultLLMEndpoint
        self.llmModel = snapshot.llmModel?.isEmpty == false ? snapshot.llmModel! : Self.defaultLLMModel
        if snapshot.projects.isEmpty {
            let defaultProject = StoredProject(name: "我的文献库", colorHex: "#0E9F9F", articles: [], config: resolvedDefaultConfig)
            self.storedProjects = [defaultProject]
            self.selectedProjectID = defaultProject.id
        } else {
            self.storedProjects = snapshot.projects
            self.selectedProjectID = snapshot.projects[0].id
        }
        loadActiveProjectConfig()
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
    var pptTemplateName: String { pptVisualTemplate.name }
    var activeDrafts: [ArticleDraft] { drafts }
    var activeDraft: ArticleDraft? { drafts.first }
    var previewDraftForTemplates: ArticleDraft {
        activeDraft ?? Self.draft(from: SampleData.articles.first ?? Self.placeholderArticle)
    }
    var availableExportFields: [CanonicalField] {
        let custom = customTasks
            .map { CanonicalField(id: $0.outputFieldKey, label: $0.title, hint: "自定义加工字段：\($0.outputFieldKey)", priority: .optional) }
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var seen: Set<String> = []
        return (ExportFieldCatalog.fields + custom).filter { seen.insert($0.id).inserted }
    }
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
        saveActiveProjectConfig()
        selectedProjectID = project.id
        loadActiveProjectConfig()
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
        saveActiveProjectConfig()
        let project = StoredProject(name: finalName, colorHex: colorHex, articles: [], config: defaultProjectConfig)
        storedProjects.append(project)
        selectedProjectID = project.id
        loadActiveProjectConfig()
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
        saveActiveProjectConfig()
        let removedName = storedProjects[index].name
        storedProjects.remove(at: index)
        if selectedProjectID == id {
            selectedProjectID = storedProjects[0].id
            loadActiveProjectConfig()
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
        if drafts.isEmpty {
            items.append(AlertItem(title: "尚无数据：请导入 Excel/CSV 或从 PubMed 检索"))
        } else if items.isEmpty {
            items.append(AlertItem(title: "数据就绪，可开始 AI 加工与导出"))
        }
        return items
    }

    var queue: [QueueItem] {
        let currentIDs = drafts.enumerated().map { draftID($1, index: $0) }
        if !enrichmentQueue.isEmpty,
           enrichmentQueueDraftIDs == currentIDs,
           enrichmentQueueProjectID == selectedProjectID {
            return enrichmentQueue
        }
        return drafts.map { draft in
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
        let range: ClosedRange<Int>? = yearFrom.map { $0...3000 }
        return PubMedQueryBuilder.buildQuery(keywords: [], requiredTerms: searchTerms, yearRange: range)
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

    func pauseEnrichment() {
        guard isBusy else { return }
        isEnrichmentPaused = true
        showToast("AI 加工已暂停")
    }

    func resumeEnrichment() {
        guard isBusy else { return }
        isEnrichmentPaused = false
        showToast("AI 加工继续执行")
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

    func changeYearFrom(_ year: Int?) async {
        yearFrom = year
        if !searchTerms.isEmpty { await performSearch(page: 0) }
    }

    func changePageSize(_ size: Int) async {
        guard size != pageSize, size > 0 else { return }
        pageSize = size
        if !searchTerms.isEmpty { await performSearch(page: 0) }
        else { resetSearchPaging() }
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

    func batchImport(all: Bool) async {
        guard !isBusy, !searchTerms.isEmpty else { return }
        if all {
            isBusy = true
            progress = 0
            showToast("正在获取所有检索结果（限前100条）…")
            defer { isBusy = false }
            do {
                let limit = 100
                let result = try await pubmed.search(query: displayedQuery, sort: sortOrder, retstart: 0, retmax: limit)
                totalHits = result.total
                currentPage = 0
                guard !result.ids.isEmpty else {
                    replaceDrafts([])
                    showToast("未找到结果")
                    return
                }
                let records = try await pubmed.fetch(pmids: result.ids)
                let recognized = records.map(autoRecognize(record:))
                replaceDrafts(recognized)
                showToast("批量入库完成：共 \(records.count) 条")
                selectedSection = .dashboard
            } catch {
                showToast("批量下载失败：\(error.localizedDescription)")
            }
        } else {
            guard !selectedForExport.isEmpty else {
                showToast("请先勾选需要入库的文献")
                return
            }
            let keep = drafts.enumerated().filter { i, d in
                selectedForExport.contains(draftID(d, index: i))
            }.map { $0.element }
            replaceDrafts(keep)
            showToast("已保留提取勾选的 \(keep.count) 条文献")
            selectedSection = .dashboard
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
        enrichmentCompleted = false
        isEnrichmentPaused = false
        progress = 0

        let targetIDs = selectedForExport.isEmpty ? Set(articles.map(\.id)) : selectedForExport
        var working = drafts
        let targetIndices = working.indices.filter { targetIDs.contains(draftID(working[$0], index: $0)) }
        let total = targetIndices.count
        guard total > 0 else { showToast("请选择要加工的文献"); return }
        isBusy = true
        defer {
            isBusy = false
            isEnrichmentPaused = false
        }
        showToast("使用云端 LLM 加工中…")

        let service = enrichmentService()
        var processed = 0
        var failedCount = 0
        // 队列始终覆盖当前项目的完整文献列表：不在本次加工范围内的文献保留其现有状态（已处理/未处理），
        // 避免“仅勾选部分文献加工”后，AI 加工页只显示被选中的子集、看不到完整列表。
        let targetIndexSet = Set(targetIndices)
        enrichmentQueue = working.indices.map { idx in
            let draft = working[idx]
            let title = draft.titleEN.isEmpty ? draft.titleCN : draft.titleEN
            let displayTitle = title.isEmpty ? "(无标题)" : title
            if targetIndexSet.contains(idx) {
                return QueueItem(title: displayTitle, status: .waiting)
            }
            return QueueItem(title: displayTitle, status: draft.abstractCN.isEmpty ? .waiting : .done)
        }
        enrichmentQueueDraftIDs = working.indices.map { draftID(working[$0], index: $0) }
        enrichmentQueueProjectID = selectedProjectID

        for index in targetIndices {
            while isEnrichmentPaused {
                enrichmentQueue[index] = QueueItem(title: enrichmentQueue[index].title, status: .paused, detail: "等待继续")
                try? await Task.sleep(for: .milliseconds(250))
            }

            enrichmentQueue[index] = QueueItem(title: enrichmentQueue[index].title, status: .running, detail: "开始处理…")
            do {
                let record = Self.record(from: working[index])
                let enriched = try await service.enrich(record: record, onStep: { [weak self] step in
                    await MainActor.run {
                        guard let self, self.enrichmentQueue.indices.contains(index) else { return }
                        let title = self.enrichmentQueue[index].title
                        self.enrichmentQueue[index] = QueueItem(title: title, status: .running, detail: step)
                    }
                })
                working[index] = Self.merged(original: working[index], enriched: enriched)
                drafts = working
                processed += 1
                progress = Double(processed) / Double(total)
                enrichmentQueue[index] = QueueItem(title: enrichmentQueue[index].title, status: .done)
                persist()
            } catch {
                let message = error.localizedDescription
                enrichmentQueue[index] = QueueItem(title: enrichmentQueue[index].title, status: .failed, detail: message)
                failedCount += 1
                showToast("文献处理失败：\(message)")
            }
        }
        drafts = working
        selectedArticleID = articles.first(where: { targetIDs.contains($0.id) })?.id ?? selectedArticleID
        enrichmentCompleted = true
        persist()
        if failedCount == 0 {
            showToast("批处理完成：\(processed) 篇已更新 AI 结果")
        } else {
            showToast("批处理完成：\(processed) 篇成功，\(failedCount) 篇文献处理失败")
        }
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

    /// 批量将指定文章标记为已复核：把 confidence 提升到高可信区间。
    func markArticlesReviewed(ids: [String]) {
        guard !ids.isEmpty else { return }
        var working = drafts
        let target = Set(ids)
        for index in working.indices where target.contains(draftID(working[index], index: index)) {
            working[index].confidence = max(working[index].confidence, 0.95)
        }
        drafts = working
        persist()
        showToast("已标记复核：\(ids.count) 篇")
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

    /// 用户确认分类字典导入（可携带用户在确认界面中调整后的列角色映射；未传则使用自动识别结果）。
    func confirmClassificationImport(proposals: [ColumnProposal]? = nil) {
        guard let analysis = pendingImport, analysis.kind == .classification else { return }
        let effectiveProposals = proposals ?? analysis.proposals
        let scheme = ImportAnalyzer.classificationScheme(from: analysis, proposals: effectiveProposals)
        topicTreeNodes = Self.nodes(from: scheme)
        let count = ClassificationEngine.flattenPaths(in: scheme).count
        pendingImport = nil
        persist()
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

    /// 打开文件选择面板导入 IF/分区数据表，仅返回解析结果，不修改当前项目的 `impactFactorByJournal`；
    /// 供“默认项目配置”等场景使用——由调用方自行决定写入哪个配置对象（如 `defaultConfig`）。
    func importImpactFactorTableFromPanel() -> [String: String]? {
        guard let url = openPanel(extensions: ["xlsx", "csv"]) else { return nil }
        do {
            let table = try DocumentService.importImpactFactors(from: url)
            showToast("已导入 IF 数据：\(table.count) 条")
            return table
        } catch {
            showToast("IF 导入失败：\(error.localizedDescription)")
            return nil
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
            let analysis = ImportAnalyzer.analyze(rows: rows)
            guard analysis.kind == .classification else {
                showToast("未识别到分类字典结构（需包含“主题/次级菜单/三级菜单/四级菜单”等列）")
                return
            }
            // 分析完成 → 弹出确认界面，用户可调整每列对应的分类层级后再导入
            pendingImport = analysis
        } catch {
            showToast("分类字典导入失败：\(error.localizedDescription)")
        }
    }

    /// 从行数据构建四级主题树并应用（可单元测试）。返回叶子路径数。
    @discardableResult
    func applyClassification(rows: [[String]]) -> Int {
        let scheme = ClassificationEngine.buildTree(from: rows)
        topicTreeNodes = Self.nodes(from: scheme)
        persist()
        return ClassificationEngine.flattenPaths(in: scheme).count
    }

    /// 手动新增一条主题分类路径，格式：“主题>次级>三级>四级”（也支持仅输入单个词条），无需导入 Excel。
    @discardableResult
    func addManualTopicPath(_ path: String) -> Bool {
        let parts = path.split(separator: ">").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            showToast("请输入有效的分类路径")
            return false
        }
        var node: ClassificationNode?
        for (index, title) in parts.enumerated().reversed() {
            node = ClassificationNode(title: title, level: index + 1, children: node.map { [$0] } ?? [])
        }
        guard let newRoot = node else { return false }
        let scheme = Self.scheme(from: topicTreeNodes)
        let updated = ClassificationScheme(name: scheme.name, type: scheme.type, isHierarchical: scheme.isHierarchical, items: scheme.items + [newRoot])
        topicTreeNodes = Self.nodes(from: updated)
        persist()
        showToast("已添加主题分类：\(path)")
        return true
    }

    /// 新增一条自定义研究类型词条（去重/去空白）。
    func addCustomStudyTerm(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !customStudyTerms.contains(trimmed) else {
            showToast("该词条已存在")
            return
        }
        customStudyTerms.append(trimmed)
        persist()
        showToast("已添加研究类型词条：\(trimmed)")
    }

    /// 移除一条自定义研究类型词条。
    func removeCustomStudyTerm(_ term: String) {
        customStudyTerms.removeAll { $0 == term }
        persist()
    }

    func chooseTemplate() {
        guard let url = openPanel(extensions: ["pptx"]) else { return }
        pptTemplateURL = url
        persist()
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
            let columns = activeProjectConfig().exportColumns
            try DocumentService.exportExcel(articles: articlesToExport, columns: columns, to: url)
            showToast("已导出 Excel 交付表：\(articlesToExport.count) 篇")
        } catch {
            showToast("导出失败：\(error.localizedDescription)")
        }
    }

    func exportPPTX() {
        guard !drafts.isEmpty else { showToast("暂无可导出的文献"); return }
        guard let output = savePanel(suggestedName: "MedEditAI-onepage.pptx") else { return }
        do {
            let mapping = activeProjectConfig().pptPlaceholders
            try DocumentService.exportPPTX(articles: articlesToExport, mapping: mapping, visualTemplate: pptVisualTemplate, to: output)
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
        let provider: LLMProviding
        if let injected = llmProvider {
            provider = injected
        } else {
            let resolvedEndpoint = URL(string: llmEndpoint.trimmingCharacters(in: .whitespacesAndNewlines))
                ?? URL(string: Self.defaultLLMEndpoint)!
            let resolvedModel = llmModel.trimmingCharacters(in: .whitespacesAndNewlines)
            provider = OpenAICompatibleLLM(
                apiKey: apiKey,
                model: resolvedModel.isEmpty ? Self.defaultLLMModel : resolvedModel,
                endpoint: resolvedEndpoint,
                session: {
#if DEBUG
                    if let s = sessionForTesting { return s }
#endif
                    return .shared
                }(),
                templates: promptTemplates
            )
        }
        return EnrichmentService(
            llm: provider,
            topicScheme: Self.scheme(from: topicTreeNodes),
            customStudyTerms: customStudyTerms,
            impactFactorByJournal: impactFactorByJournal,
            enabledTasks: Set(tasks.filter(\.isEnabled).map(\.key)),
            customTasks: customTasks
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

    private var activeProjectConfigIndex: Int? {
        storedProjects.firstIndex(where: { $0.id == selectedProjectID })
    }

    private func activeProjectConfig() -> ProjectConfig {
        if let index = activeProjectConfigIndex, let config = storedProjects[index].config {
            return config
        }
        return defaultProjectConfig
    }

    private func loadActiveProjectConfig() {
        let config = activeProjectConfig()
        promptTemplates = config.promptTemplates
        impactFactorByJournal = config.impactFactorByJournal
        customStudyTerms = config.customStudyTerms
        topicTreeNodes = config.topicScheme.map(Self.nodes(from:)) ?? []
        pptTemplateURL = config.pptTemplatePath.map(URL.init(fileURLWithPath:))
        pptVisualTemplate = config.pptVisualTemplate
        exportColumns = config.exportColumns
        pptPlaceholderMappings = config.pptPlaceholders
        customTasks = config.customTasks
    }

    private func saveActiveProjectConfig() {
        guard let index = activeProjectConfigIndex else { return }
        storedProjects[index].config = ProjectConfig(
            promptTemplates: promptTemplates,
            impactFactorByJournal: impactFactorByJournal,
            customStudyTerms: customStudyTerms,
            topicScheme: Self.scheme(from: topicTreeNodes),
            pptTemplatePath: pptTemplateURL?.path,
            pptVisualTemplate: pptVisualTemplate,
            exportColumns: exportColumns,
            pptPlaceholders: pptPlaceholderMappings,
            customTasks: customTasks
        )
    }

    private func persist() {
        saveActiveProjectConfig()
        try? store.save(makeSnapshot())
    }

    private func makeSnapshot() -> LibrarySnapshot {
        LibrarySnapshot(
            projects: storedProjects,
            customStudyTerms: customStudyTerms,
            impactFactorByJournal: impactFactorByJournal,
            promptTemplates: promptTemplates,
            topicScheme: Self.scheme(from: topicTreeNodes),
            apiKey: apiKey,
            ncbiApiKey: ncbiApiKey,
            llmEndpoint: llmEndpoint,
            llmModel: llmModel,
            defaultProjectConfig: defaultProjectConfig
        )
    }

    func saveDefaultProjectConfig(_ config: ProjectConfig) {
        defaultProjectConfig = config
        persist()
        showToast("已保存默认项目配置")
    }

    /// 保存系统级密钥与 LLM 接口配置（API Key / 接口地址 / 模型），使其在重启后仍生效。
    /// 直接写入快照，不触发项目配置回写，避免在设置页逐字输入时反复重建项目配置、抖动界面。
    func persistSystemKeys() {
        try? store.save(makeSnapshot())
    }

    func makeCurrentProjectConfig() -> ProjectConfig {
        ProjectConfig(
            promptTemplates: promptTemplates,
            impactFactorByJournal: impactFactorByJournal,
            customStudyTerms: customStudyTerms,
            topicScheme: Self.scheme(from: topicTreeNodes),
            pptTemplatePath: pptTemplateURL?.path,
            pptVisualTemplate: pptVisualTemplate,
            exportColumns: exportColumns,
            pptPlaceholders: pptPlaceholderMappings,
            customTasks: customTasks
        )
    }

    func updatePPTVisualTemplate(_ template: PPTVisualTemplate) {
        pptVisualTemplate = template
        persist()
    }

    func updateExportColumns(_ columns: [ExportColumnConfig]) {
        exportColumns = columns
        persist()
    }

    func updatePPTPlaceholderMappings(_ mappings: [PPTPlaceholderMapping]) {
        pptPlaceholderMappings = mappings
        persist()
    }

    func updateCustomTasks(_ tasks: [CustomProcessingTask]) {
        customTasks = tasks
        persist()
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
        if let customFields = enriched.customFields, !customFields.isEmpty { result.customFields = customFields }
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
            keywords: article.keywords.isEmpty ? nil : article.keywords,
            customFields: article.customFields.isEmpty ? nil : article.customFields
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
            keywords: draft.keywords ?? "",
            customFields: draft.customFields ?? [:]
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
