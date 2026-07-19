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

    // MARK: - E2E3 从仪表盘导航到检索中心并输入检索词

    func testNavigateToSearchAndType() {
        let app = launchApp()
        let startSearch = app.buttons["btn-start-search"]
        XCTAssertTrue(startSearch.waitForExistence(timeout: 10))
        startSearch.click()

        let title = app.staticTexts["page-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "检索中心")

        let field = app.textFields["field-search"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["btn-run-search"].exists)
    }

    // MARK: - E2E4 侧栏导航（可访问性标识）

    func testSidebarNavigationToLibrary() {
        let app = launchApp()
        let navLibrary = element("nav-library", in: app)
        XCTAssertTrue(navLibrary.waitForExistence(timeout: 10))
        navLibrary.click()

        let title = app.staticTexts["page-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.label, "文献库")
    }

    // MARK: - E2E5 项目管理：新建项目

    func testAddProjectFromSidebar() {
        let app = launchApp()
        let addButton = app.buttons["btn-add-project"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10))
        addButton.click()

        let field = app.textFields["field-new-project"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "应弹出新建项目对话框")
        field.click()
        // 使用 ASCII 名称，避免 CI 无中文输入法导致的键入问题
        field.typeText("Oncology")

        app.buttons["创建"].click()

        // 新项目名应出现在侧栏
        XCTAssertTrue(app.staticTexts["Oncology"].waitForExistence(timeout: 10))
    }
}
