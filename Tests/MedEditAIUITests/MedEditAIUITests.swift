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

    func testAddProjectFromSidebar() {
        let app = launchApp()
        // 分区头中的图标按钮以“任意类型 + 标识”查询更稳，避免 AX 类型差异
        let addButton = element("btn-add-project", in: app)
        XCTAssertTrue(addButton.waitForExistence(timeout: 15))
        addButton.click()

        // 先等“创建”按钮出现，确认对话框已弹出（比直接找输入框更稳）
        let createButton = app.buttons["创建"].firstMatch
        XCTAssertTrue(createButton.waitForExistence(timeout: 12), "应弹出新建项目对话框")

        // sheet 内的输入框用 app.textFields 查询（generic descendants 不一定进入 sheet）
        let field = app.textFields["field-new-project"].firstMatch
        if field.waitForExistence(timeout: 8) {
            field.click()
            // 使用 ASCII 名称，避免 CI 无中文输入法导致的键入问题
            field.typeText("Oncology")
        }
        createButton.click()

        // 新项目名应出现在侧栏（用 label 包含匹配，兼容按钮/静态文本等元素类型）
        let predicate = NSPredicate(format: "label CONTAINS %@", "Oncology")
        let created = app.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssertTrue(created.waitForExistence(timeout: 10), "新建项目应出现在侧栏")
    }
}
