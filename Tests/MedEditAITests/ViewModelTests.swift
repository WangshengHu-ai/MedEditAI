import XCTest
@testable import MedEditAI

/// 覆盖用户反馈的三大问题对应的功能点：
/// 1) 交互/状态真实生效（按钮、选择、开关）；
/// 2) 默认空状态、导入真实替换数据、派生展示数据不再硬编码；
/// 3) 视图模型层可测的业务逻辑闭环（检索/加工/导入/导出守卫）。
@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - Test doubles

    /// 可注入的假 PubMed 数据源，支持分页/排序断言，避免真实网络。
    private final class MockPubMed: PubMedFetching {
        let allIDs: [String]
        let records: [PubMedRecord]
        var lastSort: PubMedSort?
        var lastRetstart: Int?
        var lastRetmax: Int?
        var lastQuery: String?

        init(ids: [String] = [], records: [PubMedRecord] = []) {
            self.allIDs = ids
            self.records = records
        }

        func search(query: String, sort: PubMedSort, retstart: Int, retmax: Int) async throws -> PubMedSearchResult {
            lastQuery = query
            lastSort = sort
            lastRetstart = retstart
            lastRetmax = retmax
            let page = Array(allIDs.dropFirst(retstart).prefix(retmax))
            return PubMedSearchResult(total: allIDs.count, ids: page)
        }

        func fetch(pmids: [String]) async throws -> [PubMedRecord] {
            let matched = records.filter { pmids.contains($0.pmid) }
            return matched.isEmpty ? records : matched
        }
    }

    private struct MockLLM: LLMProviding {
        var customTaskResult: String = "风险分层：高"
        var delayNanos: UInt64 = 0

        func translate(_ request: TranslationRequest) async throws -> TranslationResult {
            if delayNanos > 0 { try? await Task.sleep(nanoseconds: delayNanos) }
            return TranslationResult(titleCN: "中文-\(request.title)", abstractCN: "中文摘要", keywordsCN: request.keywords)
        }

        func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult {
            TopicClassificationResult(topicPath: candidatePaths.first ?? "未分类", confidence: 0.9)
        }

        func classifyStudyType(title: String, abstract: String, candidateTerms: [String]) async throws -> StudyTypeClassificationResult {
            StudyTypeClassificationResult(studyType: "队列研究", confidence: 0.82)
        }

        func runCustomTask(promptTemplate: String, title: String, abstract: String, keywords: [String]) async throws -> String {
            customTaskResult
        }
    }

    private struct FailingLLM: LLMProviding {
        struct Boom: LocalizedError { var errorDescription: String? { "模拟失败" } }

        func translate(_ request: TranslationRequest) async throws -> TranslationResult { throw Boom() }
        func classifyTopic(title: String, abstract: String, candidatePaths: [String]) async throws -> TopicClassificationResult { throw Boom() }
        func classifyStudyType(title: String, abstract: String, candidateTerms: [String]) async throws -> StudyTypeClassificationResult { throw Boom() }
        func runCustomTask(promptTemplate: String, title: String, abstract: String, keywords: [String]) async throws -> String { throw Boom() }
    }

    private func record(pmid: String, title: String = "Study", journal: String = "Heart Rhythm") -> PubMedRecord {
        PubMedRecord(
            pmid: pmid, title: title, abstract: "electroporation ablation study",
            authors: ["Bates AP"], journal: journal, pubDate: "2026",
            doi: "10.1/\(pmid)", keywords: ["ablation"], meshTerms: [], references: []
        )
    }

    /// 每个 VM 使用独立的临时持久化文件，互不污染，也不写入 Application Support。
    private func makeViewModel(pubmed: PubMedFetching = MockPubMed()) -> AppViewModel {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mededitai-tests-\(UUID().uuidString).json")
        let store = LibraryStore(fileURL: tempURL)
        return AppViewModel(pubmed: pubmed, store: store)
    }

    private func makeViewModel(pubmed: PubMedFetching = MockPubMed(), llmProvider: LLMProviding) -> AppViewModel {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mededitai-tests-\(UUID().uuidString).json")
        let store = LibraryStore(fileURL: tempURL)
        return AppViewModel(pubmed: pubmed, llmProvider: llmProvider, store: store)
    }

    // MARK: - FP1 空状态默认（不再污染 demo 数据）

    func testStartsEmptyByDefault() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.hasData)
        XCTAssertEqual(vm.articleCount, 0)
        XCTAssertTrue(vm.articles.isEmpty)
        XCTAssertTrue(vm.topicTree.isEmpty)
        XCTAssertNil(vm.selectedArticleID)
    }

    func testLoadSampleDataPopulatesEverything() {
        let vm = makeViewModel()
        vm.loadSampleData()
        XCTAssertTrue(vm.hasData)
        XCTAssertEqual(vm.articleCount, SampleData.articles.count)
        XCTAssertFalse(vm.topicTree.isEmpty)
        XCTAssertFalse(vm.impactFactorByJournal.isEmpty)
        XCTAssertNotNil(vm.selectedArticleID)
    }

    func testClearAllReturnsToEmptyState() {
        let vm = makeViewModel()
        vm.loadSampleData()
        vm.clearAll()
        XCTAssertFalse(vm.hasData)
        XCTAssertEqual(vm.articleCount, 0)
        XCTAssertNil(vm.selectedArticleID)
        XCTAssertTrue(vm.articles.isEmpty)
    }

    // MARK: - FP2 导入替换数据并全局反映

    func testReplaceDraftsReplacesLibrary() {
        let vm = makeViewModel()
        let rows = [
            ["序号", "标题", "摘要/研究简介-原文", "摘要/研究简介-翻译", "研究类型"],
            ["1", "The Biophysics of RF Ablation", "abstract en", "摘要翻译", "综述"]
        ]
        vm.replaceDrafts(DocumentService.articles(from: rows))
        XCTAssertEqual(vm.articleCount, 1)
        XCTAssertEqual(vm.articles.first?.titleEN, "The Biophysics of RF Ablation")
    }

    func testImportReplacesExistingDataInsteadOfAppending() {
        let vm = makeViewModel()
        vm.loadSampleData()
        XCTAssertEqual(vm.articleCount, SampleData.articles.count)

        let rows = [["标题"], ["Only One"]]
        vm.replaceDrafts(DocumentService.articles(from: rows))
        XCTAssertEqual(vm.articleCount, 1)
        XCTAssertEqual(vm.articles.first?.titleEN, "Only One")
    }

    // MARK: - FP3 派生仪表盘统计（非硬编码）

    func testStatsAreLiveDerivedFromData() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.stats.first { $0.title == "文献总量" }?.value, "0")

        vm.loadSampleData()
        XCTAssertEqual(vm.stats.first { $0.title == "文献总量" }?.value, "\(SampleData.articles.count)")
        XCTAssertEqual(vm.stats.first { $0.title == "待复核" }?.value, "\(vm.pendingReviewCount)")
        XCTAssertEqual(vm.stats.first { $0.title == "IF 条目" }?.value, "\(vm.impactFactorByJournal.count)")
    }

    func testPendingReviewCountsOnlyLowConfidence() {
        let vm = makeViewModel()
        vm.loadSampleData()
        // 示例数据中仅“土豆模型”一篇为低置信度（<0.7）。
        XCTAssertEqual(vm.pendingReviewCount, 1)
    }

    // MARK: - FP4 派生提醒

    func testAlertsShowEmptyPromptWhenNoData() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.alerts.contains { $0.title.contains("尚无数据") })
    }

    func testAlertsReflectDataState() {
        let vm = makeViewModel()
        vm.loadSampleData()
        XCTAssertTrue(vm.alerts.contains { $0.title.contains("待复核") })
        XCTAssertTrue(vm.alerts.contains { $0.title.contains("IF 数据集") })
        XCTAssertFalse(vm.alerts.contains { $0.title.contains("尚无数据") })
    }

    // MARK: - FP5 派生队列

    func testQueueReflectsArticles() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.queue.isEmpty)

        vm.loadSampleData()
        XCTAssertFalse(vm.queue.isEmpty)
        XCTAssertEqual(vm.queue.count, vm.articleCount)
        XCTAssertEqual(vm.queue.first?.title, SampleData.articles.first?.titleEN)
    }

    // MARK: - FP6 透明检索式（派生自输入）

    func testSearchTermsSplitOnAnd() {
        let vm = makeViewModel()
        vm.searchText = "pulsed field ablation AND atrial fibrillation"
        XCTAssertEqual(vm.searchTerms, ["pulsed field ablation", "atrial fibrillation"])
    }

    func testEmptySearchTextYieldsEmptyTerms() {
        let vm = makeViewModel()
        vm.searchText = "    "
        XCTAssertTrue(vm.searchTerms.isEmpty)
    }

    func testDisplayedQueryIsTransparentAndMatchesInput() {
        let vm = makeViewModel()
        vm.searchText = "pulsed field ablation AND atrial fibrillation"
        vm.yearFrom = 2024
        let query = vm.displayedQuery
        XCTAssertTrue(query.contains("\"pulsed field ablation\"[Title/Abstract]"))
        XCTAssertTrue(query.contains("\"atrial fibrillation\"[Title/Abstract]"))
        XCTAssertTrue(query.contains("2024:3000[pdat]"))
    }

    // MARK: - 起始年份支持不指定

    func testDefaultYearFromIsNilAndQueryOmitsYearClause() {
        let vm = makeViewModel()
        XCTAssertNil(vm.yearFrom)
        vm.searchText = "pulsed field ablation"
        XCTAssertFalse(vm.displayedQuery.contains("[pdat]"))
    }

    func testChangeYearFromNilClearsYearFilterAndRefetches() async {
        let ids = (1...5).map(String.init)
        let mock = MockPubMed(ids: ids, records: ids.map { record(pmid: $0) })
        let vm = makeViewModel(pubmed: mock)
        vm.searchText = "ablation"

        await vm.changeYearFrom(2020)
        XCTAssertEqual(vm.yearFrom, 2020)
        XCTAssertTrue((mock.lastQuery ?? "").contains("2020:3000[pdat]"))

        await vm.changeYearFrom(nil)
        XCTAssertNil(vm.yearFrom)
        XCTAssertFalse(vm.displayedQuery.contains("[pdat]"))
        XCTAssertFalse((mock.lastQuery ?? "").contains("[pdat]"))   // 清除后重新检索，不再限制年份
    }

    // MARK: - FP8 加工任务开关

    func testToggleTaskFlipsEnabledState() {
        let vm = makeViewModel()
        let first = vm.tasks[0]
        let before = first.isEnabled
        vm.toggleTask(first)
        XCTAssertEqual(vm.tasks[0].isEnabled, !before)
    }

    // MARK: - FP11 IF 导入并回填

    func testSetImpactFactorsReappliesToExistingArticles() {
        let vm = makeViewModel()
        vm.loadSampleData()
        vm.setImpactFactors(["heartrhythm": "9.9"])
        let heartRhythm = vm.articles.first { $0.journal == "Heart Rhythm" }
        XCTAssertEqual(heartRhythm?.impactFactor, "9.9")
        XCTAssertEqual(vm.impactFactorByJournal.count, 1)
    }

    // MARK: - FP12 分类字典构建四级树

    func testApplyClassificationBuildsTopicTree() {
        let vm = makeViewModel()
        let rows = [
            ["主题", "次级菜单", "三级菜单", "四级菜单", "呈现方式", "文献备注"],
            ["Science of PFA", "原理和影响因素", "PFA发展史和生物物理学原理", "叶子A", "PPT", "备注1"],
            ["Science of PFA", "原理和影响因素", "PFA发展史和生物物理学原理", "叶子B", "PPT", "备注2"]
        ]
        let count = vm.applyClassification(rows: rows)
        XCTAssertEqual(count, 2)
        XCTAssertFalse(vm.topicTree.isEmpty)
    }

    // MARK: - FP14 空数据导出/加工守卫（提示而非崩溃）

    func testExportExcelWithNoDataShowsToast() {
        let vm = makeViewModel()
        vm.exportExcel()
        XCTAssertEqual(vm.toastMessage, "暂无可导出的文献")
    }

    func testExportPPTXWithNoDataShowsToast() {
        let vm = makeViewModel()
        vm.exportPPTX()
        XCTAssertEqual(vm.toastMessage, "暂无可导出的文献")
    }

    func testRunEnrichmentWithNoDataIsNoop() async {
        let vm = makeViewModel()
        await vm.runEnrichment()
        XCTAssertFalse(vm.hasData)
    }

    // MARK: - FP15 选择态

    func testChooseArticleUpdatesSelection() {
        let vm = makeViewModel()
        vm.loadSampleData()
        let target = vm.articles[1]
        vm.chooseArticle(target)
        XCTAssertEqual(vm.selectedArticleID, target.id)
        XCTAssertEqual(vm.selectedArticle?.id, target.id)
    }

    func testToggleExportSelectionControlsExportSet() {
        let vm = makeViewModel()
        vm.loadSampleData()
        let article = vm.articles[0]
        XCTAssertFalse(vm.isSelectedForExport(article))

        vm.toggleExportSelection(article)
        XCTAssertTrue(vm.isSelectedForExport(article))
        XCTAssertEqual(vm.articlesToExport.count, 1)

        vm.toggleExportSelection(article)
        XCTAssertFalse(vm.isSelectedForExport(article))
        // 空选择时导出全部。
        XCTAssertEqual(vm.articlesToExport.count, vm.articleCount)
    }

    // MARK: - 检索闭环（注入 Mock，无网络）

    func testRunSearchPopulatesSearchResultsNotLibrary() async {
        let records = [
            PubMedRecord(
                pmid: "1", title: "Electroporation review of ablation", abstract: "electroporation ablation",
                authors: ["Bates AP"], journal: "Heart Rhythm", pubDate: "2026",
                doi: "10.1/x", keywords: ["ablation"], meshTerms: [], references: []
            )
        ]
        let vm = makeViewModel(pubmed: MockPubMed(ids: ["1"], records: records))
        vm.searchText = "ablation"
        await vm.runSearch()
        XCTAssertTrue(vm.hasSearchResults)
        XCTAssertEqual(vm.searchResults.count, 1)
        XCTAssertEqual(vm.searchResults.first?.pmid, "1")
        XCTAssertFalse(vm.hasData)                 // 检索结果不进入文献库
        XCTAssertEqual(vm.articleCount, 0)
    }

    func testRunSearchWithEmptyResultsKeepsEmptyAndToasts() async {
        let vm = makeViewModel(pubmed: MockPubMed(ids: [], records: []))
        vm.searchText = "ablation"
        await vm.runSearch()
        XCTAssertFalse(vm.hasSearchResults)
        XCTAssertEqual(vm.toastMessage, "未找到结果")
    }

    // MARK: - FP18 检索分页与总命中数

    func testSearchReportsTotalHitsAndFirstPage() async {
        let ids = (1...60).map(String.init)
        let vm = makeViewModel(pubmed: MockPubMed(ids: ids, records: ids.map { record(pmid: $0) }))
        vm.searchText = "ablation"
        await vm.runSearch()
        XCTAssertEqual(vm.totalHits, 60)
        XCTAssertEqual(vm.currentPage, 0)
        XCTAssertEqual(vm.totalPages, 3)          // ceil(60 / 25)
        XCTAssertEqual(vm.searchResults.count, 25)
        XCTAssertTrue(vm.canGoNextPage)
        XCTAssertFalse(vm.canGoPrevPage)
    }

    func testSearchPaginationNextAndPrev() async {
        let ids = (1...60).map(String.init)
        let mock = MockPubMed(ids: ids, records: ids.map { record(pmid: $0) })
        let vm = makeViewModel(pubmed: mock)
        vm.searchText = "ablation"
        await vm.runSearch()
        await vm.nextPage()
        XCTAssertEqual(vm.currentPage, 1)
        XCTAssertEqual(mock.lastRetstart, 25)
        XCTAssertEqual(vm.searchResults.count, 25)
        XCTAssertTrue(vm.canGoPrevPage)
        await vm.nextPage()
        XCTAssertEqual(vm.currentPage, 2)
        XCTAssertEqual(vm.searchResults.count, 10)       // 60 - 50
        XCTAssertFalse(vm.canGoNextPage)
        await vm.prevPage()
        XCTAssertEqual(vm.currentPage, 1)
    }

    func testChangeSortPassesSortAndResetsToFirstPage() async {
        let ids = (1...60).map(String.init)
        let mock = MockPubMed(ids: ids, records: ids.map { record(pmid: $0) })
        let vm = makeViewModel(pubmed: mock)
        vm.searchText = "ablation"
        await vm.runSearch()
        await vm.nextPage()
        XCTAssertEqual(vm.currentPage, 1)
        await vm.changeSort(.pubDate)
        XCTAssertEqual(vm.sortOrder, .pubDate)
        XCTAssertEqual(mock.lastSort, .pubDate)
        XCTAssertEqual(vm.currentPage, 0)         // 排序变更回到首页
    }

    // MARK: - FP29 检索结果自定义每页条数

    func testChangePageSizeUpdatesSizeAndRefetchesFirstPage() async {
        let ids = (1...60).map(String.init)
        let mock = MockPubMed(ids: ids, records: ids.map { record(pmid: $0) })
        let vm = makeViewModel(pubmed: mock)
        vm.searchText = "ablation"
        await vm.runSearch()
        await vm.nextPage()
        XCTAssertEqual(vm.currentPage, 1)

        await vm.changePageSize(50)
        XCTAssertEqual(vm.pageSize, 50)
        XCTAssertEqual(mock.lastRetmax, 50)
        XCTAssertEqual(vm.currentPage, 0)          // 每页条数变更回到首页
        XCTAssertEqual(vm.searchResults.count, 50)
        XCTAssertEqual(vm.totalPages, 2)           // ceil(60 / 50)
    }

    func testChangeYearFromRefetchesImmediately() async {
        let ids = (1...10).map(String.init)
        let mock = MockPubMed(ids: ids, records: ids.map { record(pmid: $0) })
        let vm = makeViewModel(pubmed: mock)
        vm.searchText = "ablation"
        await vm.runSearch()

        await vm.changeYearFrom(2012)
        XCTAssertEqual(vm.yearFrom, 2012)
        XCTAssertEqual(vm.currentPage, 0)
        XCTAssertTrue((mock.lastQuery ?? "").contains("2012:3000[pdat]"))
    }

    func testPageSizeSupports1000() async {
        let ids = (1...120).map(String.init)
        let mock = MockPubMed(ids: ids, records: ids.map { record(pmid: $0) })
        let vm = makeViewModel(pubmed: mock)
        vm.searchText = "ablation"
        await vm.runSearch()
        await vm.changePageSize(1000)
        XCTAssertEqual(vm.pageSize, 1000)
        XCTAssertEqual(mock.lastRetmax, 1000)
        XCTAssertEqual(vm.searchResults.count, 120)
    }

    func testChangePageSizeWithoutActiveSearchJustResetsPaging() async {
        let vm = makeViewModel()
        await vm.changePageSize(10)
        XCTAssertEqual(vm.pageSize, 10)
        XCTAssertEqual(vm.currentPage, 0)
        XCTAssertEqual(vm.totalHits, 0)
    }

    // MARK: - FP19 项目管理与切换

    func testAddProjectSwitchesToNewEmptyProject() {
        let vm = makeViewModel()
        vm.loadSampleData()
        XCTAssertTrue(vm.hasData)
        let before = vm.projects.count
        vm.addProject(name: "肿瘤免疫")
        XCTAssertEqual(vm.projects.count, before + 1)
        XCTAssertEqual(vm.selectedProject.name, "肿瘤免疫")
        XCTAssertFalse(vm.hasData)                 // 新项目从空开始
    }

    func testSwitchingProjectSwitchesData() {
        let vm = makeViewModel()
        vm.loadSampleData()                        // 默认项目 A 载入示例
        let projectA = vm.selectedProject
        vm.addProject(name: "空项目")               // 切换到空项目 B
        XCTAssertFalse(vm.hasData)
        vm.chooseProject(projectA)                 // 切回 A
        XCTAssertEqual(vm.selectedProject.id, projectA.id)
        XCTAssertTrue(vm.hasData)
        XCTAssertEqual(vm.articleCount, SampleData.articles.count)
    }

    func testRenameProject() {
        let vm = makeViewModel()
        vm.renameProject(id: vm.selectedProjectID, to: "心电生理库")
        XCTAssertEqual(vm.selectedProject.name, "心电生理库")
    }

    func testNewProjectInheritsDefaultConfig() {
        let vm = makeViewModel()
        var config = ProjectConfig.default
        config.customStudyTerms = ["动物实验"]
        config.promptTemplates.translationSystem = "default-system"
        config.pptVisualTemplate = PPTVisualTemplate(name: "默认一页纸模板", accentHex: "#112233", fontFamily: "Songti SC", titleFontSize: 26)
        vm.saveDefaultProjectConfig(config)
        let projectID = vm.addProject(name: "继承项目")
        XCTAssertEqual(vm.selectedProjectID, projectID)
        XCTAssertEqual(vm.customStudyTerms, ["动物实验"])
        XCTAssertEqual(vm.promptTemplates.translationSystem, "default-system")
        XCTAssertEqual(vm.pptVisualTemplate.name, "默认一页纸模板")
        XCTAssertEqual(vm.pptTemplateName, "默认一页纸模板")
        XCTAssertEqual(vm.pptVisualTemplate.fontFamily, "Songti SC")
        XCTAssertEqual(vm.pptVisualTemplate.titleFontSize, 26)
    }

    func testUpdatingPPTVisualTemplatePersistsAsCurrentProjectTemplate() {
        let vm = makeViewModel()
        let template = PPTVisualTemplate(
            name: "产品内模板", accentHex: "#445566", metadataBackgroundHex: "#F0F1F2", ctaText: "查看原文",
            fontFamily: "Helvetica Neue", topicFontSize: 20, titleFontSize: 28, subtitleFontSize: 18,
            bodyFontSize: 14, metadataFontSize: 12, captionFontSize: 10
        )
        vm.updatePPTVisualTemplate(template)
        XCTAssertEqual(vm.pptTemplateName, "产品内模板")
        XCTAssertEqual(vm.pptVisualTemplate.accentHex, "#445566")
        XCTAssertEqual(vm.pptVisualTemplate.fontFamily, "Helvetica Neue")
        XCTAssertEqual(vm.pptVisualTemplate.titleFontSize, 28)
        XCTAssertEqual(vm.pptVisualTemplate.captionFontSize, 10)
        let currentConfig = vm.makeCurrentProjectConfig()
        XCTAssertEqual(currentConfig.pptVisualTemplate.name, "产品内模板")
        XCTAssertEqual(currentConfig.pptVisualTemplate.fontFamily, "Helvetica Neue")
        XCTAssertEqual(currentConfig.pptVisualTemplate.bodyFontSize, 14)
    }

    func testDeleteProjectKeepsAtLeastOne() {
        let vm = makeViewModel()
        vm.deleteProject(id: vm.selectedProjectID) // 仅一个项目 -> 拒绝删除
        XCTAssertEqual(vm.projects.count, 1)
        let newID = vm.addProject(name: "临时")
        XCTAssertEqual(vm.projects.count, 2)
        vm.deleteProject(id: newID)
        XCTAssertEqual(vm.projects.count, 1)
    }

    func testProjectsPersistAcrossViewModelReload() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mededitai-persist-\(UUID().uuidString).json")
        let vm1 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        vm1.renameProject(id: vm1.selectedProjectID, to: "PFA 库")
        vm1.addProject(name: "第二库")

        let vm2 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertEqual(vm2.projects.count, 2)
        XCTAssertTrue(vm2.projects.contains { $0.name == "PFA 库" })
        XCTAssertTrue(vm2.projects.contains { $0.name == "第二库" })
    }

    // MARK: - FP20 待复核手动编辑并保存

    func testSaveArticleEditsUpdatesFieldsAndMarksReviewed() {
        let vm = makeViewModel()
        vm.loadSampleData()
        XCTAssertEqual(vm.pendingReviewCount, 1)   // “土豆模型”一篇低置信度
        let target = vm.articles.first { $0.confidence == .low }!
        vm.saveArticleEdits(
            id: target.id, topic: "人工复核主题", titleCN: "人工中文标题",
            abstractCN: "人工中文摘要", studyType: "综述", product: "PFA",
            note: "已人工确认", markReviewed: true
        )
        let updated = vm.articles.first { $0.id == target.id }!
        XCTAssertEqual(updated.topic, "人工复核主题")
        XCTAssertEqual(updated.titleCN, "人工中文标题")
        XCTAssertEqual(updated.abstractCN, "人工中文摘要")
        XCTAssertEqual(updated.note, "已人工确认")
        XCTAssertEqual(updated.confidence, .high)  // 标记复核后提升置信度
        XCTAssertEqual(vm.pendingReviewCount, 0)   // 不再待复核
    }

    func testMarkArticlesReviewedClearsPendingReview() {
        let vm = makeViewModel()
        vm.loadSampleData()
        let low = vm.articles.filter { $0.confidence == .low }
        XCTAssertEqual(low.count, 1)
        vm.markArticlesReviewed(ids: low.map(\.id))
        XCTAssertEqual(vm.pendingReviewCount, 0)
    }

    // MARK: - FP21 AI 加工仅处理选中并写回卡片

    func testEnrichmentProcessesOnlySelectedArticles() async {
        let vm = makeViewModel()
        vm.apiKey = "sk-mock"
        // 该测试用的 mock 对所有请求只返回翻译 JSON，因此仅启用翻译任务，
        // 避免研究类型/主题分类调用因解析非预期响应而抛错、导致整篇 enrich 失败。
        vm.tasks = vm.tasks.map { task in
            var updated = task
            updated.isEnabled = task.key == "translate"
            return updated
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PromptCapturingProtocol.self]
        vm.sessionForTesting = URLSession(configuration: config)

        let rows = [
            ["标题", "研究类型"],
            ["Pulsed field ablation outcomes", ""],
            ["Radiofrequency ablation review", ""]
        ]
        vm.replaceDrafts(DocumentService.articles(from: rows))
        XCTAssertEqual(vm.articleCount, 2)

        let first = vm.articles[0]
        vm.toggleExportSelection(first)            // 仅选第一篇
        await vm.runEnrichment()

        let processed = vm.articles.first { $0.id == first.id }!
        let untouched = vm.articles.first { $0.id != first.id }!
        XCTAssertFalse(processed.titleCN.isEmpty)  // 第一篇被翻译
        XCTAssertTrue(untouched.titleCN.isEmpty)   // 第二篇未处理
    }

    func testEnrichmentProcessesAllWhenNoneSelected() async {
        let vm = makeViewModel()
        vm.apiKey = "sk-mock"
        // 同上：mock 仅支持翻译响应，故只启用翻译任务。
        vm.tasks = vm.tasks.map { task in
            var updated = task
            updated.isEnabled = task.key == "translate"
            return updated
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PromptCapturingProtocol.self]
        vm.sessionForTesting = URLSession(configuration: config)

        let rows = [
            ["标题", "研究类型"],
            ["Pulsed field ablation outcomes", ""],
            ["Radiofrequency ablation review", ""]
        ]
        vm.replaceDrafts(DocumentService.articles(from: rows))
        await vm.runEnrichment()
        XCTAssertTrue(vm.articles.allSatisfy { !$0.titleCN.isEmpty })
    }

    // MARK: - AI 加工页面始终展示完整文献列表

    func testEnrichmentQueueShowsFullListWhenOnlySubsetSelected() async {
        let vm = makeViewModel(llmProvider: MockLLM())
        vm.apiKey = "sk-mock"
        let rows = [["标题"], ["Alpha study"], ["Beta study"], ["Gamma study"]]
        vm.replaceDrafts(DocumentService.articles(from: rows))
        XCTAssertEqual(vm.articleCount, 3)

        let target = vm.articles[1]
        vm.toggleExportSelection(target)   // 仅选中第二篇进行加工
        await vm.runEnrichment()

        // AI 加工页应始终展示当前项目的完整文献列表，而不是只展示本次加工的子集。
        XCTAssertEqual(vm.queue.count, 3)
        XCTAssertEqual(vm.queue.filter { $0.status == .done }.count, 1)
        XCTAssertEqual(vm.queue.filter { $0.status == .waiting }.count, 2)
    }

    func testEnrichmentQueueDoesNotReuseStaleCacheAfterProjectSwitch() async {
        let vm = makeViewModel(llmProvider: MockLLM())
        vm.apiKey = "sk-mock"
        vm.replaceDrafts(DocumentService.articles(from: [["标题"], ["Project A Study"]]))
        await vm.runEnrichment()
        XCTAssertEqual(vm.queue.count, 1)
        XCTAssertEqual(vm.queue.first?.title, "Project A Study")
        XCTAssertEqual(vm.queue.first?.status, .done)

        vm.addProject(name: "第二项目")   // 自动切换到新项目（空文献库）
        vm.replaceDrafts(DocumentService.articles(from: [["标题"], ["Project B Study"]]))   // 与项目A数量相同但内容不同

        // 不应复用项目A遗留的队列标题/状态（即使数量恰巧相同）。
        XCTAssertEqual(vm.queue.count, 1)
        XCTAssertEqual(vm.queue.first?.title, "Project B Study")
        XCTAssertEqual(vm.queue.first?.status, .waiting)
    }

    func testCustomTasksRoundTripToArticleAndExportFields() async {
        let vm = makeViewModel(llmProvider: MockLLM())
        vm.apiKey = "sk-mock"
        vm.tasks = vm.tasks.map { task in
            var updated = task
            updated.isEnabled = task.key == "translate"
            return updated
        }
        vm.customTasks = [CustomProcessingTask(title: "风险分层", outputFieldKey: "riskLevel", prompt: "{title}")]
        let rows = [["标题"], ["Pulsed field ablation outcomes"]]
        vm.replaceDrafts(DocumentService.articles(from: rows))

        await vm.runEnrichment()

        XCTAssertEqual(vm.articles.first?.customFields["riskLevel"], "风险分层：高")
        XCTAssertTrue(vm.availableExportFields.contains { $0.id == "riskLevel" })
    }

    func testEnrichmentFailureShowsFailedQueueItem() async {
        let vm = makeViewModel(llmProvider: FailingLLM())
        vm.apiKey = "sk-mock"
        vm.tasks = vm.tasks.map { task in
            var updated = task
            updated.isEnabled = task.key == "translate"
            return updated
        }
        vm.replaceDrafts(DocumentService.articles(from: [["标题"], ["Only One"]]))

        await vm.runEnrichment()

        XCTAssertEqual(vm.queue.first?.status, .failed)
        XCTAssertTrue(vm.toastMessage?.contains("文献处理失败") == true)
    }

    func testEnrichmentSupportsPauseAndResume() async {
        let vm = makeViewModel(llmProvider: MockLLM(delayNanos: 150_000_000))
        vm.apiKey = "sk-mock"
        vm.tasks = vm.tasks.map { task in
            var updated = task
            updated.isEnabled = task.key == "translate"
            return updated
        }
        let rows = [["标题"], ["One"], ["Two"]]
        vm.replaceDrafts(DocumentService.articles(from: rows))

        let work = Task { await vm.runEnrichment() }
        try? await Task.sleep(nanoseconds: 40_000_000)
        vm.pauseEnrichment()
        try? await Task.sleep(nanoseconds: 220_000_000)
        XCTAssertTrue(vm.isEnrichmentPaused)
        XCTAssertTrue(vm.queue.contains { $0.status == .paused })
        vm.resumeEnrichment()
        await work.value

        XCTAssertTrue(vm.enrichmentCompleted)
        XCTAssertFalse(vm.isBusy)
        XCTAssertTrue(vm.articles.allSatisfy { !$0.titleCN.isEmpty })
    }

    // MARK: - LLM 接口/模型可配置 + 单篇进度回调

    func testDefaultLLMEndpointAndModelAreBigModel() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.llmEndpoint, "https://open.bigmodel.cn/api/paas/v4/chat/completions")
        XCTAssertEqual(vm.llmModel, "glm-4-flash")
    }

    func testLLMEndpointAndModelPersistAcrossReload() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-config-\(UUID().uuidString).json")
        let vm1 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        vm1.llmEndpoint = "https://example.com/v1/chat/completions"
        vm1.llmModel = "glm-4"
        vm1.apiKey = "id.secret"
        vm1.persistSystemKeys()

        let vm2 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertEqual(vm2.llmEndpoint, "https://example.com/v1/chat/completions")
        XCTAssertEqual(vm2.llmModel, "glm-4")
        XCTAssertEqual(vm2.apiKey, "id.secret")
    }

    func testEnrichmentServiceReportsPerArticleProgressSteps() async throws {
        let service = EnrichmentService(
            llm: MockLLM(),
            topicScheme: ClassificationScheme(name: "主题", type: .topic, isHierarchical: true, items: []),
            customStudyTerms: [],
            impactFactorByJournal: [:],
            enabledTasks: ["translate", "topic"]
        )
        let collector = StepCollector()
        _ = try await service.enrich(record: record(pmid: "1", title: "PFA study")) { step in
            await collector.add(step)
        }
        let steps = await collector.steps
        XCTAssertTrue(steps.contains { $0.contains("翻译") }, "应上报翻译进度")
        XCTAssertTrue(steps.contains { $0.contains("主题") }, "应上报主题分类进度")
    }

    // MARK: - FP22 导入自动识别文献字段

    func testAutoRecognizeFillsEmptyFields() {
        let vm = makeViewModel()
        let draft = ArticleDraft(
            topic: "", titleEN: "Randomized controlled trial of pulsed field ablation",
            titleCN: "", abstractEN: "randomized controlled trial", abstractCN: "",
            citation: "", authors: "A", date: "2026", studyType: "", journal: "Heart Rhythm",
            impactFactor: nil, quartile: nil, pmid: "9", url: nil, confidence: 1.0,
            product: "", evidence: "", note: ""
        )
        let recognized = vm.autoRecognize(draft: draft)
        XCTAssertEqual(recognized.studyType, "随机对照试验")   // 识别研究设计
        XCTAssertEqual(recognized.product, "PFA")            // 识别产品
    }

    // MARK: - FP23 导入映射分析与用户确认

    func testAnalyzeDetectsArticleMappingWithSample() {
        let rows = [
            ["标题", "自定义列X"],
            ["The Biophysics of RF Ablation", "手动中文摘要"]
        ]
        let analysis = ImportAnalyzer.analyze(rows: rows)
        XCTAssertEqual(analysis.kind, .articles)
        let titleProposal = analysis.proposals.first { $0.sourceHeader == "标题" }
        XCTAssertEqual(titleProposal?.field, "titleEN")           // 自动映射标题
        XCTAssertEqual(titleProposal?.sample, "The Biophysics of RF Ablation")  // 带示例值
        let customProposal = analysis.proposals.first { $0.sourceHeader == "自定义列X" }
        XCTAssertEqual(customProposal?.field, "")                 // 未识别列默认忽略
    }

    func testAnalyzeDetectsClassificationDictionary() {
        let rows = [
            ["主题", "次级菜单", "三级菜单", "四级菜单", "呈现方式", "文献备注"],
            ["Science of PFA", "原理", "史", "叶子A", "PPT", "备注1"],
            ["Science of PFA", "原理", "史", "叶子B", "PPT", "备注2"]
        ]
        let analysis = ImportAnalyzer.analyze(rows: rows)
        XCTAssertEqual(analysis.kind, .classification)
        XCTAssertEqual(analysis.classificationPathCount, 2)
    }

    func testAnalyzeUnknownForUnrecognizedColumns() {
        let analysis = ImportAnalyzer.analyze(rows: [["颜色", "尺寸"], ["红", "大"]])
        XCTAssertEqual(analysis.kind, .unknown)
    }

    func testConfirmArticleImportAppliesAdjustedMapping() {
        let rows = [
            ["标题", "自定义列X"],
            ["T1", "手动中文摘要"]
        ]
        let analysis = ImportAnalyzer.analyze(rows: rows)
        var proposals = analysis.proposals
        // 用户把“自定义列X”改映射为中文摘要
        let idx = proposals.firstIndex { $0.sourceHeader == "自定义列X" }!
        proposals[idx].field = "abstractCN"
        let drafts = ImportAnalyzer.articles(from: analysis, proposals: proposals)
        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].titleEN, "T1")
        XCTAssertEqual(drafts[0].abstractCN, "手动中文摘要")
    }

    func testImportMapsKeywordsColumn() {
        let rows = [
            ["标题", "关键词"],
            ["T1", "ablation; PFA"]
        ]
        let analysis = ImportAnalyzer.analyze(rows: rows)
        let kw = analysis.proposals.first { $0.sourceHeader == "关键词" }
        XCTAssertEqual(kw?.field, "keywords")
        let drafts = ImportAnalyzer.articles(from: analysis, proposals: analysis.proposals)
        XCTAssertEqual(drafts.first?.keywords, "ablation; PFA")
    }

    func testConfirmArticleImportReplacesDataAndClearsPending() {
        let vm = makeViewModel()
        vm.pendingImport = ImportAnalyzer.analyze(rows: [["标题", "作者"], ["T1", "A"], ["T2", "B"]])
        XCTAssertNotNil(vm.pendingImport)
        vm.confirmArticleImport(proposals: vm.pendingImport!.proposals)
        XCTAssertNil(vm.pendingImport)
        XCTAssertEqual(vm.articleCount, 2)
        XCTAssertEqual(vm.articles.first?.titleEN, "T1")
    }

    func testConfirmClassificationImportBuildsTreeAndClearsPending() {
        let vm = makeViewModel()
        vm.pendingImport = ImportAnalyzer.analyze(rows: [
            ["主题", "次级菜单", "三级菜单", "四级菜单"],
            ["Science of PFA", "原理", "史", "叶子A"],
            ["Science of PFA", "原理", "史", "叶子B"]
        ])
        XCTAssertEqual(vm.pendingImport?.kind, .classification)
        vm.confirmClassificationImport()
        XCTAssertNil(vm.pendingImport)
        XCTAssertFalse(vm.topicTree.isEmpty)
    }

    func testConfirmClassificationImportAppliesUserAdjustedColumnMapping() {
        let vm = makeViewModel()
        // 列名不是固定的“主题/次级菜单/…”，用户需要在确认界面手动指定每列对应的分类层级。
        let rows = [
            ["自定义列1", "自定义列2", "自定义列3", "自定义列4"],
            ["Science of PFA", "原理", "史", "叶子A"],
            ["Science of PFA", "原理", "史", "叶子B"]
        ]
        let analysis = ImportAnalyzer.analyze(rows: rows)
        XCTAssertEqual(analysis.kind, .unknown)   // 未识别固定列名，走通用导入分析
        vm.pendingImport = ImportAnalysis(kind: .classification, rows: rows, headerIndex: 0, proposals: [
            ColumnProposal(sourceHeader: "自定义列1", field: "topic", sample: "Science of PFA"),
            ColumnProposal(sourceHeader: "自定义列2", field: "secondary", sample: "原理"),
            ColumnProposal(sourceHeader: "自定义列3", field: "tertiary", sample: "史"),
            ColumnProposal(sourceHeader: "自定义列4", field: "quaternary", sample: "叶子A")
        ])
        vm.confirmClassificationImport(proposals: vm.pendingImport!.proposals)
        XCTAssertNil(vm.pendingImport)
        XCTAssertEqual(vm.topicTree.isEmpty, false)
        XCTAssertNotNil(ClassificationEngine.findNode(in: AppViewModel.scheme(from: vm.topicTree), title: "叶子A"))
    }

    func testCustomStudyTermsPersistAcrossReload() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("study-terms-\(UUID().uuidString).json")
        let vm1 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertTrue(vm1.customStudyTerms.isEmpty)
        vm1.addCustomStudyTerm("土豆模型")
        XCTAssertEqual(vm1.customStudyTerms, ["土豆模型"])
        vm1.addCustomStudyTerm("土豆模型")   // 去重
        XCTAssertEqual(vm1.customStudyTerms.count, 1)

        let vm2 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertEqual(vm2.customStudyTerms, ["土豆模型"])   // 重启后仍生效（此前存在但从未回读的持久化缺口）

        vm2.removeCustomStudyTerm("土豆模型")
        XCTAssertTrue(vm2.customStudyTerms.isEmpty)
    }

    func testAddAndRemoveTopicTermPersists() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("topic-terms-\(UUID().uuidString).json")
        let vm1 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertTrue(vm1.addTopicTerm("原理与生物物理学"))
        XCTAssertTrue(vm1.addTopicTerm("影响因素"))
        XCTAssertFalse(vm1.addTopicTerm("原理与生物物理学"))   // 去重
        XCTAssertFalse(vm1.addTopicTerm("   "))                 // 空输入拒绝
        XCTAssertEqual(vm1.topicTerms, ["原理与生物物理学", "影响因素"])

        vm1.removeTopicTerm("原理与生物物理学")
        XCTAssertEqual(vm1.topicTerms, ["影响因素"])

        let vm2 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertEqual(vm2.topicTerms, ["影响因素"])   // 重启后仍生效
    }

    func testCancelImportClearsPending() {
        let vm = makeViewModel()
        vm.pendingImport = ImportAnalyzer.analyze(rows: [["标题"], ["T1"]])
        XCTAssertNotNil(vm.pendingImport)
        vm.cancelImport()
        XCTAssertNil(vm.pendingImport)
    }

    func testConfirmArticleImportWithNoTitleMappingShowsToast() {
        let vm = makeViewModel()
        let analysis = ImportAnalyzer.analyze(rows: [["标题", "作者"], ["T1", "A"]])
        // 用户把标题列也改成忽略 -> 无法解析
        var proposals = analysis.proposals
        for i in proposals.indices { proposals[i].field = "" }
        vm.pendingImport = analysis
        vm.confirmArticleImport(proposals: proposals)
        XCTAssertNil(vm.pendingImport)
        XCTAssertFalse(vm.hasData)
        XCTAssertNotNil(vm.toastMessage)
    }

    // MARK: - FP24 分类树主题过滤

    private func draft(topic: String, title: String, pmid: String) -> ArticleDraft {
        ArticleDraft(
            topic: topic, titleEN: title, titleCN: "", abstractEN: "", abstractCN: "",
            citation: "", authors: "", date: "", studyType: "", journal: "",
            impactFactor: nil, quartile: nil, pmid: pmid, url: nil, confidence: 1.0,
            product: "", evidence: "", note: ""
        )
    }

    func testSelectTopicFiltersArticles() {
        let vm = makeViewModel()
        vm.replaceDrafts([
            draft(topic: "主题A", title: "T1", pmid: "1"),
            draft(topic: "主题B", title: "T2", pmid: "2")
        ])
        XCTAssertEqual(vm.filteredArticles.count, 2)   // 无筛选

        vm.selectTopic("主题A")
        XCTAssertEqual(vm.selectedTopic, "主题A")
        XCTAssertEqual(vm.filteredArticles.count, 1)
        XCTAssertEqual(vm.filteredArticles.first?.topic, "主题A")

        vm.selectTopic("主题A")   // 再次点击取消
        XCTAssertNil(vm.selectedTopic)
        XCTAssertEqual(vm.filteredArticles.count, 2)
    }

    // MARK: - FP25 项目切换导航到工作台

    func testChooseProjectNavigatesToDashboard() {
        let vm = makeViewModel()
        let first = vm.selectedProject
        vm.addProject(name: "P2")            // 切到 P2
        vm.navigate(to: .search)
        XCTAssertEqual(vm.selectedSection, .search)
        vm.chooseProject(first)              // 切回 first → 导航到工作台
        XCTAssertEqual(vm.selectedSection, .dashboard)
        XCTAssertEqual(vm.selectedProject.id, first.id)
    }

    // MARK: - FP26 示例数据不持久化

    func testLoadSampleDataIsNotPersisted() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nopersist-\(UUID().uuidString).json")
        let vm1 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        vm1.loadSampleData()
        XCTAssertTrue(vm1.hasData)

        let vm2 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertFalse(vm2.hasData)          // 示例数据未持久化，重开为空
    }

    // MARK: - FP28 AI 加工 Prompt 可查看 / 自定义

    func testDefaultPromptTemplatesContainPlaceholders() {
        let t = PromptTemplates.default
        XCTAssertTrue(t.translationUser.contains("{title}"))
        XCTAssertTrue(t.translationUser.contains("{abstract}"))
        XCTAssertTrue(t.translationUser.contains("{keywords}"))
        XCTAssertTrue(t.classificationUser.contains("{candidates}"))
        XCTAssertTrue(t.classificationUser.contains("{title}"))
        XCTAssertTrue(t.classificationUser.contains("{abstract}"))
    }

    func testTranslationPromptSubstitutesPlaceholders() {
        var t = PromptTemplates.default
        t.translationUser = "T={title} A={abstract} K={keywords}"
        let prompt = t.translationPrompt(title: "PFA 研究", abstract: "摘要", keywords: ["ablation", "PFA"])
        XCTAssertEqual(prompt, "T=PFA 研究 A=摘要 K=ablation; PFA")
        XCTAssertFalse(prompt.contains("{title}"))   // 占位符已全部替换
    }

    func testClassificationPromptSubstitutesPlaceholders() {
        var t = PromptTemplates.default
        t.classificationUser = "C={candidates} T={title} A={abstract}"
        let prompt = t.classificationPrompt(title: "标题", abstract: "摘要", candidates: ["A>B", "C>D"])
        XCTAssertEqual(prompt, "C=A>B | C>D T=标题 A=摘要")
    }

    func testCustomTemplatesFlowIntoCloudLLMPrompt() async throws {
        // 用自定义模板构造云端 Provider，用 Mock 拦截请求体，验证 Prompt 真正被替换后发出。
        var templates = PromptTemplates.default
        templates.translationUser = "翻译这段：{title}"
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PromptCapturingProtocol.self]
        let session = URLSession(configuration: config)
        let llm = OpenAICompatibleLLM(
            apiKey: "sk-test",
            endpoint: URL(string: "https://example.com/v1/chat/completions")!,
            session: session,
            templates: templates
        )
        _ = try await llm.translate(
            TranslationRequest(title: "PFA 研究", abstract: "摘要", keywords: [])
        )
        let sentBody = PromptCapturingProtocol.lastBody ?? ""
        XCTAssertTrue(sentBody.contains("翻译这段：PFA 研究"))   // 自定义模板已生效
    }

    func testSavePromptTemplatesPersistsAcrossReload() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("prompt-persist-\(UUID().uuidString).json")
        let vm1 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        var custom = PromptTemplates.default
        custom.translationUser = "自定义翻译 {title}"
        vm1.savePromptTemplates(custom)

        let vm2 = AppViewModel(pubmed: MockPubMed(), store: LibraryStore(fileURL: tempURL))
        XCTAssertEqual(vm2.promptTemplates.translationUser, "自定义翻译 {title}")
    }

    func testResetPromptTemplatesRestoresDefault() {
        let vm = makeViewModel()
        var custom = PromptTemplates.default
        custom.translationSystem = "changed"
        vm.savePromptTemplates(custom)
        XCTAssertEqual(vm.promptTemplates.translationSystem, "changed")
        vm.resetPromptTemplates()
        XCTAssertEqual(vm.promptTemplates, PromptTemplates.default)
    }
}

/// 线程安全收集 enrich 单篇处理进度步骤，供进度回调测试断言。
actor StepCollector {
    private(set) var steps: [String] = []
    func add(_ step: String) { steps.append(step) }
}

/// 拦截 URLSession 请求体，供 Prompt 替换测试断言实际发出的内容。
final class PromptCapturingProtocol: URLProtocol {
    static var lastBody: String?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let stream = request.httpBodyStream {
            stream.open()
            var data = Data()
            let bufferSize = 4096
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            PromptCapturingProtocol.lastBody = String(decoding: data, as: UTF8.self)
        } else if let body = request.httpBody {
            PromptCapturingProtocol.lastBody = String(decoding: body, as: UTF8.self)
        }
        let json = "{\"choices\":[{\"message\":{\"content\":\"{\\\"titleCN\\\":\\\"中\\\",\\\"abstractCN\\\":\\\"\\\",\\\"keywordsCN\\\":[]}\"}}]}"
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: json.data(using: .utf8)!)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
