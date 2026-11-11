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

    /// 4.0 Design 却下（iPad で「カスタム演習」の分野チップが潰れた）の確認用。
    /// 分野の多い資格で、カスタム演習画面を撮影する。
    func testCaptureCustomPractice() {
        for exam in ["itp", "fe", "aws", "g", "pmos"] {
            launch(exam: exam)
            XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
            tab("演習")
            let entry = app.staticTexts["カスタム演習"]
            if entry.waitForExistence(timeout: 10) {
                entry.tap()
                shot("custom_\(exam)")
            } else {
                XCTFail("カスタム演習の入口が見つからない: \(exam)")
            }
            app.terminate()
        }
    }

    /// 学習の記録カード（ホーム）と学習カレンダーの見た目確認用
    func testCaptureStudyCalendar() {
        launch(exam: "itp")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        tab("ホーム"); shot("10_home_record")
        let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '学習の記録'")).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        card.tap()
        XCTAssertTrue(app.navigationBars["学習カレンダー"].waitForExistence(timeout: 10))
        shot("11_calendar_all")
        app.swipeUp(); shot("12_calendar_bottom")
    }

    /// 聞き流し（一覧と再生画面）の見た目確認用
    func testCaptureListening() {
        launch(exam: "itp")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        tab("ホーム")
        let entry = app.staticTexts["聞き流し"].firstMatch
        if !entry.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.navigationBars["聞き流し"].waitForExistence(timeout: 10))
        shot("20_listening_hub")
        let mix = app.buttons["通勤ミックス3分を再生"]
        XCTAssertTrue(mix.waitForExistence(timeout: 10))
        mix.tap()
        sleep(4)
        shot("21_listening_player")
        app.swipeUp()
        sleep(2)
        shot("22_listening_next")
    }

    /// ホームの資格切り替え（文字つきボタン→半分シート）と、設定の学習リマインドの確認用
    func testCaptureSwitcherAndReminder() {
        launch(exam: "aws")
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 20))
        tab("ホーム"); shot("30_home_top")
        let sw = app.buttons["資格を切り替える"]
        if sw.waitForExistence(timeout: 10) { sw.tap(); shot("31_switcher_sheet") }
        let close = app.buttons["閉じる"]
        if close.waitForExistence(timeout: 5) { close.tap() }
        tab("設定")
        app.swipeUp()
        shot("32_settings_reminder")
    }
}
