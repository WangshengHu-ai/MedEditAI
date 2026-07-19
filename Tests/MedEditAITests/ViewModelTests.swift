import XCTest
@testable import MedEditAI

/// 覆盖用户反馈的三大问题对应的功能点：
/// 1) 交互/状态真实生效（按钮、选择、开关）；
/// 2) 默认空状态、导入真实替换数据、派生展示数据不再硬编码；
/// 3) 视图模型层可测的业务逻辑闭环（检索/加工/导入/导出守卫）。
@MainActor
final class ViewModelTests: XCTestCase {

    // MARK: - Test doubles

    /// 可注入的假 PubMed 数据源，避免真实网络。
    private final class MockPubMed: PubMedFetching {
        let ids: [String]
        let records: [PubMedRecord]
        init(ids: [String] = [], records: [PubMedRecord] = []) {
            self.ids = ids
            self.records = records
        }
        func search(query: String, maxResults: Int) async throws -> [String] { ids }
        func fetch(pmids: [String]) async throws -> [PubMedRecord] { records }
    }

    /// 每个 VM 使用独立的临时持久化文件，互不污染，也不写入 Application Support。
    private func makeViewModel(pubmed: PubMedFetching = MockPubMed()) -> AppViewModel {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mededitai-tests-\(UUID().uuidString).json")
        let store = LibraryStore(fileURL: tempURL)
        return AppViewModel(pubmed: pubmed, store: store)
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
        XCTAssertLessThanOrEqual(vm.queue.count, 6)
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

    // MARK: - FP7 检索过滤器开关

    func testToggleFilterAddsAndRemoves() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.enabledFilters.contains("综述"))
        vm.toggleFilter("综述")
        XCTAssertTrue(vm.enabledFilters.contains("综述"))
        vm.toggleFilter("综述")
        XCTAssertFalse(vm.enabledFilters.contains("综述"))
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

    func testRunSearchWithMockPopulatesLibrary() async {
        let records = [
            PubMedRecord(
                pmid: "1", title: "Electroporation review of ablation", abstract: "electroporation ablation",
                authors: ["Bates AP"], journal: "Heart Rhythm", pubDate: "2026",
                doi: "10.1/x", keywords: ["ablation"], meshTerms: [], references: []
            )
        ]
        let vm = makeViewModel(pubmed: MockPubMed(ids: ["1"], records: records))
        await vm.runSearch()
        XCTAssertTrue(vm.hasData)
        XCTAssertEqual(vm.articleCount, 1)
        XCTAssertEqual(vm.articles.first?.pmid, "1")
    }

    func testRunSearchWithEmptyResultsKeepsEmptyAndToasts() async {
        let vm = makeViewModel(pubmed: MockPubMed(ids: [], records: []))
        await vm.runSearch()
        XCTAssertFalse(vm.hasData)
        XCTAssertEqual(vm.toastMessage, "未找到结果")
    }
}
