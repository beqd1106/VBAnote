import XCTest

/// App Store 掲載用スクリーンショットを撮る UI テスト。
/// 撮影結果は環境変数 SCREENSHOT_DIR（未指定なら /tmp/vbanote_shots）に PNG で保存する。
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outDir: URL!

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments += ["-ScreenshotSeed"]
        app.launch()
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp/vbanote_shots"
        outDir = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    private func shot(_ name: String) {
        sleep(2)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: outDir.appendingPathComponent("\(name).png"))
        let a = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        a.name = name; a.lifetime = .keepAlways
        add(a)
    }

    private func tab(_ label: String) {
        let b = app.tabBars.buttons[label]
        if b.waitForExistence(timeout: 10) { b.tap() }
    }

    func testCaptureStoreScreenshots() {
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))

        tab("ホーム");  shot("01_home")

        tab("演習")
        let domain = app.staticTexts["マクロとVBAの基本"]
        if domain.waitForExistence(timeout: 10) { domain.tap() }
        let choice = app.buttons["choice_1"]
        if choice.waitForExistence(timeout: 10) {
            shot("02_question")
            choice.tap()
            let check = app.buttons["答え合わせ"]
            if check.waitForExistence(timeout: 5) { check.tap() }
            shot("03_explanation")
        }
        app.navigationBars.buttons.firstMatch.tap()

        tab("学ぶ");    shot("04_learn")
        tab("分析");    shot("05_analysis")
    }
}
