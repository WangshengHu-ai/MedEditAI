import XCTest

/// 端到端 UI 测试：启动真实 App，通过可访问性标识驱动关键工作流，验证功能可用。
/// 以 `-uitest-reset` 启动，使用一次性临时存储，保证每次干净、隔离。
final class MedEditAIUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func loadSampleData(in app: XCUIApplication) {
        let loadButton = app.buttons["btn-load-sample"]
        XCTAssertTrue(loadButton.waitForExistence(timeout: 10))
        loadButton.click()
    }

    // MARK: - E2E1 启动与窗口

    func testAppLaunchesWithSidebar() {
        let app = launchApp()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        // 侧栏“工作台”分组存在
        XCTAssertTrue(app.staticTexts["工作台"].waitForExistence(timeout: 10))
    }

    // MARK: - E2E2 空状态 -> 载入示例数据 -> 清空

    func testLoadSampleDataThenClear() {
        let app = launchApp()
        let loadButton = app.buttons["btn-load-sample"]
        XCTAssertTrue(loadButton.waitForExistence(timeout: 10), "空状态应显示“载入示例数据”")
        loadButton.click()

        let clearButton = app.buttons["btn-clear-data"]
        XCTAssertTrue(clearButton.waitForExistence(timeout: 10), "载入后应显示“清空数据”")
        clearButton.click()

        XCTAssertTrue(loadButton.waitForExistence(timeout: 10), "清空后应回到空状态")
    }

    // MARK: - E2E3 从仪表盘导航到检索中心

    func testNavigateToSearchShowsSearchControls() {
        let app = launchApp()
        let startSearch = app.buttons["btn-start-search"]
        XCTAssertTrue(startSearch.waitForExistence(timeout: 10))
        startSearch.click()

        // 用检索页特有控件判断导航成功，避免依赖标题标签
        XCTAssertTrue(app.textFields["field-search"].waitForExistence(timeout: 10), "应进入检索中心并显示检索框")
        XCTAssertTrue(app.buttons["btn-run-search"].waitForExistence(timeout: 5))
    }

    // MARK: - E2E4 侧栏导航到文献库（可访问性标识）

    func testSidebarNavigationToLibrary() {
        let app = launchApp()
        let navLibrary = element("nav-library", in: app)
        XCTAssertTrue(navLibrary.waitForExistence(timeout: 10))
        navLibrary.click()

        // 文献库页特有的“导入 Excel”按钮出现即证明切换成功
        XCTAssertTrue(app.buttons["btn-import-excel"].waitForExistence(timeout: 10), "应切换到文献库")
    }

    // MARK: - E2E5 项目管理：新建项目

    func testAddProjectCreatesNamedProject() {
        let app = launchApp()
        let addButton = app.buttons["btn-add-project"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 15))
        addButton.click()

        let nameField = app.textFields["项目名称"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.click()
        nameField.typeText("肿瘤免疫")
        // macOS 上带 TextField 的 SwiftUI .alert 在 XCUITest 无障碍树里不一定归类为 alert（可能是 dialog/sheet），
        // 故不能用 app.alerts.buttons；改用全局 label 匹配 + firstMatch，既避免“Multiple matching”又不受 alert 限制。
        let createButton = app.buttons.matching(NSPredicate(format: "label == %@", "创建")).firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 10))
        createButton.click()

        let predicate = NSPredicate(format: "label CONTAINS %@", "肿瘤免疫")
        let created = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 10), "应创建并显示新项目")
    }

    func testSearchShowsManualYearAndSelectingResultUpdatesDetail() {
        let app = launchApp()
        loadSampleData(in: app)
        element("nav-search", in: app).click()

        XCTAssertTrue(app.textFields["field-year-from"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.popUpButtons["picker-page-size"].waitForExistence(timeout: 10))

        let articleTitle = "Latest Advances and Ongoing Challenges in Pulsed Field Ablation"
        let articleButton = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", articleTitle)).firstMatch
        XCTAssertTrue(articleButton.waitForExistence(timeout: 10))
        articleButton.click()
        XCTAssertTrue(app.staticTexts["脉冲电场消融的最新进展与持续挑战"].waitForExistence(timeout: 10))
    }

    func testLibraryCanFilterLowConfidenceAndMarkReviewed() {
        let app = launchApp()
        loadSampleData(in: app)
        element("nav-library", in: app).click()

        let lowConfidenceTitle = "Evaluation of variable inter-pulse delays for pulsed field ablation"
        XCTAssertTrue(app.buttons["btn-low-confidence-filter"].waitForExistence(timeout: 10))
        app.buttons["btn-low-confidence-filter"].click()
        // 标题渲染在整行 Button 的 label 内，用按钮 label 匹配而非 staticText。
        let lowRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", lowConfidenceTitle)).firstMatch
        XCTAssertTrue(lowRow.waitForExistence(timeout: 10))

        let markReviewed = app.buttons["btn-mark-reviewed"]
        XCTAssertTrue(markReviewed.isEnabled)
        markReviewed.click()
        // 唯一的低置信度文献被标记复核后，低置信度筛选结果为空 → 展示空状态“文献库为空”。
        XCTAssertTrue(app.staticTexts["文献库为空"].waitForExistence(timeout: 10))
    }

    func testEnrichShowsFullQueueAndCustomTaskEditor() {
        let app = launchApp()
        loadSampleData(in: app)
        element("nav-enrich", in: app).click()

        XCTAssertTrue(app.buttons["btn-run-enrichment"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Internal atrial shock delivery by standard diagnostic electrophysiology catheters in goats"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["field-custom-task-title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["btn-add-custom-task"].waitForExistence(timeout: 10))
    }

    func testSlidesAndSettingsExposeTemplateEditorsAndDefaultConfig() {
        let app = launchApp()
        loadSampleData(in: app)

        element("nav-slides", in: app).click()
        XCTAssertTrue(app.staticTexts["PPT 样式模板"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Excel 导出模板"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["PPT 占位符映射"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["field-ppt-font-family"].waitForExistence(timeout: 10), "应支持编辑 PPT 字体")
        XCTAssertTrue(element("stepper-ppt-font-title", in: app).waitForExistence(timeout: 10), "应支持编辑标题字号")

        app.buttons["btn-settings"].click()
        XCTAssertTrue(app.buttons["btn-save-default-config"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["当前项目配置在哪里修改"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["导出交付 Excel"].exists)
        XCTAssertFalse(app.buttons["导出 onepage PPT"].exists)
    }
}
