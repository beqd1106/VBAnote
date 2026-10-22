import XCTest

/// App Store 掲載用スクリーンショットを撮る UI テスト。
/// 撮影結果は環境変数 SCREENSHOT_DIR（未指定なら /tmp/shikakunote_shots）に PNG で保存する。
/// 学習中の資格は起動引数 -selectedExamKey で指定する（UserDefaults の引数ドメインで上書きされる）。
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!
    private var outDir: URL!

    override func setUp() {
        continueAfterFailure = true
        let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] ?? "/tmp/shikakunote_shots"
        outDir = URL(fileURLWithPath: dir)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    private func launch(exam: String) {
        app = XCUIApplication()
        app.launchArguments += ["-selectedExamKey", exam, "-ScreenshotSeed"]
        app.launch()
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
        // 1枚目：収録している資格の一覧（未選択の状態で起動）
        launch(exam: "none")
        XCTAssertTrue(app.buttons["exam_itp"].waitForExistence(timeout: 20))
        shot("01_exams")
        app.terminate()

        // 2枚目以降：ITパスポートを学習中の状態
        launch(exam: "itp")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        tab("ホーム");  shot("02_home")

        tab("演習")
        let domain = app.staticTexts["企業活動と法務"]
        if domain.waitForExistence(timeout: 10) { domain.tap() }
        let choice = app.buttons["choice_1"]
        if choice.waitForExistence(timeout: 10) {
            shot("03_question")
            choice.tap()
            let check = app.buttons["答え合わせ"]
            if check.waitForExistence(timeout: 5) { check.tap() }
            shot("04_explanation")
        }
        app.navigationBars.buttons.firstMatch.tap()

        tab("分析");    shot("05_analysis")
    }
}
