import XCTest
@testable import VBAnote

/// 純粋ロジックのユニットテスト（永続化やバンドルに依存しない部分を検証）。
final class LogicTests: XCTestCase {

    // MARK: - 間隔反復

    func testSpacedRepetitionAdvancesOnCorrect() {
        let r = SpacedRepetition.next(currentLevel: 0, correct: true)
        XCTAssertEqual(r.level, 1)               // 段階が進む
    }

    func testSpacedRepetitionResetsOnWrong() {
        let now = Date()
        let r = SpacedRepetition.next(currentLevel: 3, correct: false, now: now)
        XCTAssertEqual(r.level, 0)               // 間違えたら段階0へ
        XCTAssertEqual(r.nextDate, now)          // その場で復習対象になる
    }

    /// 間違えた問題はその日のうちに復習リストへ出てくる（翌日まで待たされない）
    func testWrongAnswerBecomesDueImmediately() {
        let now = Date()
        let r = SpacedRepetition.next(currentLevel: 0, correct: false, now: now)
        let item = ReviewItem(questionId: "q1", nextReviewDate: r.nextDate,
                              reviewLevel: r.level, lastResultCorrect: false)
        XCTAssertTrue(item.isDue, "間違えた問題はすぐ復習できる状態であるべき")
    }

    /// ヒントを使って正解した場合は段階を進めない（自力で解けたわけではないため）
    func testHintedCorrectKeepsLevel() {
        let plain = SpacedRepetition.next(currentLevel: 2, correct: true)
        XCTAssertEqual(plain.level, 3)

        let hinted = SpacedRepetition.next(currentLevel: 2, correct: true, usedHint: true)
        XCTAssertEqual(hinted.level, 2, "ヒントつきの正解では段階を据え置く")
    }

    // MARK: - ヒント

    private func makeQuestion(id: String = "q-hint",
                              choices: [String] = ["選択肢A", "選択肢B", "選択肢C", "選択肢D"],
                              correct: [Int] = [0],
                              beginnerNote: String? = nil,
                              service: String = "ストレージ") -> QuizQuestion {
        QuizQuestion(id: id, question: "機械学習について正しいものはどれか。",
                     choices: choices, correctAnswers: correct,
                     explanation: "解説", source: nil, wrongChoiceExplanations: [:],
                     domain: ExamDomain.allCases[0], service: service, difficulty: 2,
                     tags: ["ストレージ"], beginnerNote: beginnerNote)
    }

    func testHintUsesBeginnerNoteWhenSafe() {
        let q = makeQuestion(beginnerNote: "まずは保存する期間に注目しましょう。")
        XCTAssertEqual(HintBuilder.focusHint(for: q), "まずは保存する期間に注目しましょう。")
    }

    /// 正解をそのまま書いている補足はヒントに使わない（答えが見えてしまうため）
    func testHintDoesNotRevealAnswer() {
        let q = makeQuestion(beginnerNote: "答えは選択肢Aです。")
        let hint = HintBuilder.focusHint(for: q)
        XCTAssertFalse(hint.contains("選択肢A"))
        XCTAssertFalse(hint.isEmpty)
    }

    func testHintFallsBackToTheme() {
        let q = makeQuestion(beginnerNote: nil)
        XCTAssertTrue(HintBuilder.focusHint(for: q).contains("ストレージ"))
    }

    /// しぼり込みは正解を消さず、単一選択では2択まで減らす
    func testEliminationKeepsCorrectAndLeavesTwoChoices() {
        let q = makeQuestion()
        let dropped = HintBuilder.eliminatedChoices(for: q)
        XCTAssertFalse(dropped.contains(0), "正解を消してはいけない")
        XCTAssertEqual(q.choices.count - dropped.count, 2, "単一選択は2択まで絞る")
    }

    /// 複数選択では正解をすべて残し、不正解の一部だけ消す
    func testEliminationOnMultipleSelect() {
        let q = makeQuestion(choices: ["A", "B", "C", "D", "E"], correct: [0, 1])
        let dropped = HintBuilder.eliminatedChoices(for: q)
        XCTAssertTrue(dropped.isDisjoint(with: [0, 1]))
        XCTAssertFalse(dropped.isEmpty)
        XCTAssertLessThan(dropped.count, 3)
    }

    /// 同じ問題なら何度開いても同じ選択肢が消える
    func testEliminationIsDeterministic() {
        let q = makeQuestion()
        XCTAssertEqual(HintBuilder.eliminatedChoices(for: q),
                       HintBuilder.eliminatedChoices(for: q))
    }

    /// 2択の問題では絞り込みを提示しない
    func testEliminationUnavailableForTwoChoices() {
        let q = makeQuestion(choices: ["はい", "いいえ"], correct: [0])
        XCTAssertTrue(HintBuilder.eliminatedChoices(for: q).isEmpty)
        XCTAssertFalse(HintBuilder.canEliminate(q))
    }

    func testSpacedRepetitionIntervalsAreIncreasing() {
        let intervals = (0..<SpacedRepetition.intervals.count).map { SpacedRepetition.interval(forLevel: $0) }
        for i in 1..<intervals.count {
            XCTAssertGreaterThan(intervals[i], intervals[i-1], "間隔は段階とともに広がるべき")
        }
    }

    func testSpacedRepetitionLevelCapped() {
        let r = SpacedRepetition.next(currentLevel: 99, correct: true)
        XCTAssertEqual(r.level, SpacedRepetition.intervals.count - 1)
    }

    // MARK: - 合格可能性スコア

    func testPassProbabilityZeroWhenNoStudy() {
        let input = PassProbability.Inputs(
            correctRateByDomain: [:], latestMockScaledScore: nil,
            reviewCompletionRate: 1.0, studyStreak: 0, totalAnswered: 0)
        XCTAssertEqual(PassProbability.score(input), 0)
    }

    func testPassProbabilityCappedForFewAnswers() {
        // 全分野満点でも学習量が少なければ上限で抑えられる
        let perfect = Dictionary(uniqueKeysWithValues: ExamDomain.allCases.map { ($0, 1.0) })
        let input = PassProbability.Inputs(
            correctRateByDomain: perfect, latestMockScaledScore: 1000,
            reviewCompletionRate: 1.0, studyStreak: 20, totalAnswered: 10)
        XCTAssertLessThanOrEqual(PassProbability.score(input), 35)
    }

    func testPassProbabilityHighWhenWellPrepared() {
        let good = Dictionary(uniqueKeysWithValues: ExamDomain.allCases.map { ($0, 0.85) })
        let input = PassProbability.Inputs(
            correctRateByDomain: good, latestMockScaledScore: 820,
            reviewCompletionRate: 1.0, studyStreak: 14, totalAnswered: 120)
        XCTAssertGreaterThanOrEqual(PassProbability.score(input), 70)
    }

    // MARK: - 配点の整合性

    func testDomainWeightsSumToOne() {
        let sum = ExamDomain.allCases.reduce(0.0) { $0 + $1.weight }
        XCTAssertEqual(sum, 1.0, accuracy: 0.001, "公式配点の合計は100%になるべき")
    }

    // MARK: - 収録している全資格

    /// どの資格に切り替えても、コンテンツが読めて分野・ロードマップ・重要用語が噛み合っている
    func testEveryExamLoadsConsistentContent() {
        let original = ExamContext.current
        defer { ExamContext.activate(original) }
        XCTAssertGreaterThanOrEqual(ExamContext.all.count, 9)
        for exam in ExamContext.all {
            ExamContext.activate(exam)
            let repo = ContentRepository.shared
            XCTAssertFalse(repo.questions.isEmpty, "\(exam.key): 問題が空")
            XCTAssertFalse(repo.lessons.isEmpty, "\(exam.key): レッスンが空")
            let sum = ExamDomain.allCases.reduce(0.0) { $0 + $1.weight }
            XCTAssertEqual(sum, 1.0, accuracy: 0.001, "\(exam.key): 配点の合計が100%でない")
            let domains = Set(ExamDomain.allCases.map(\.rawValue))
            XCTAssertTrue(repo.questions.allSatisfy { domains.contains($0.domain.rawValue) },
                          "\(exam.key): 分野にない domain の問題がある")
            XCTAssertEqual(ExamInfo.roadmap.count, 8, "\(exam.key): ロードマップは8週")
            XCTAssertTrue(ExamInfo.roadmap.allSatisfy { !$0.domains.isEmpty }, "\(exam.key): 分野のない週がある")
            for id in ExamInfo.keyTermIds {
                XCTAssertTrue(repo.terms.contains { $0.id == id }, "\(exam.key): 重要用語 \(id) が無い")
            }
            XCTAssertFalse(repo.buildMockExam(count: ExamInfo.mockCount).isEmpty, "\(exam.key): 模試が組めない")
        }
    }

    /// 他の資格の分野名は、いまの資格の分野として扱わない（進捗が混ざらない）
    func testDomainFromAnotherExamIsRejected() {
        let original = ExamContext.current
        defer { ExamContext.activate(original) }
        let itp = ExamContext.all.first { $0.key == "itp" }!
        ExamContext.activate(itp)
        XCTAssertNotNil(ExamDomain(rawValue: "strategyCorp"))
        XCTAssertNil(ExamDomain(rawValue: "cloudConcepts"), "AWSの分野はITパスポートでは無効")
    }

    // MARK: - 学習プラン

    func testRoadmapMatchesPlanDuration() {
        for plan in StudyPlanType.allCases {
            let roadmap = PlanFactory.roadmap(for: plan)
            XCTAssertEqual(roadmap.count, plan.durationWeeks)
            XCTAssertEqual(roadmap.first?.week, 1)
            XCTAssertEqual(roadmap.last?.week, plan.durationWeeks)
        }
    }

    func testCurrentWeekClampsWithinPlan() {
        let start = Calendar.current.date(byAdding: .day, value: -200, to: .now)!
        let week = PlanFactory.currentWeek(startedAt: start, plan: .standard8)
        XCTAssertLessThanOrEqual(week, 8)
        XCTAssertGreaterThanOrEqual(week, 1)
    }

    // MARK: - 学習カレンダー

    func testStudyLevelThresholds() {
        let day = Calendar.current.startOfDay(for: .now)
        func level(_ q: Int, lessons: Int = 0) -> Int {
            var r = DailyStudyRecord(day: day); r.questions = q; r.lessonsCompleted = lessons
            return r.level
        }
        XCTAssertEqual(level(0), 0)
        XCTAssertEqual(level(1), 1)
        XCTAssertEqual(level(9), 1)
        XCTAssertEqual(level(10), 2)
        XCTAssertEqual(level(30), 3)
        XCTAssertEqual(level(60), 4)
        XCTAssertEqual(level(0, lessons: 2), 2)   // レッスン1つ＝5問分
    }

    func testEstimateMinutesIgnoresLongBreaks() {
        let t0 = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(DailyStudyRecord.estimateMinutes([]), 0)
        XCTAssertEqual(DailyStudyRecord.estimateMinutes([t0]), 1)
        // 1分おきに5問 → 30秒 + 4分 ≒ 5分
        let steady = (0..<5).map { t0.addingTimeInterval(Double($0) * 60) }
        XCTAssertEqual(DailyStudyRecord.estimateMinutes(steady), 5)
        // 2時間空いても休憩とみなし、空白は数えない
        let withBreak = [t0, t0.addingTimeInterval(60), t0.addingTimeInterval(7200)]
        XCTAssertEqual(DailyStudyRecord.estimateMinutes(withBreak), 2)
    }

    func testStudyRecordCSVFillsGapsAndHasHeader() throws {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        var r = DailyStudyRecord(day: twoDaysAgo); r.questions = 4; r.correct = 3
        let url = try StudyRecordCSV.write(records: [twoDaysAgo: r])
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(3)), [0xEF, 0xBB, 0xBF])   // Excel用のBOM（文字列に読むと自動で除かれる）
        let text = String(decoding: data.dropFirst(3), as: UTF8.self)
        let lines = text.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        XCTAssertTrue(lines[0].hasPrefix("日付,"))
        XCTAssertEqual(lines.count, 4)               // 見出し＋3日分（学習しなかった日も入る）
        XCTAssertTrue(lines[1].contains(",4,3,75,"))  // 4問中3問正解＝75%
    }

    // MARK: - 連続学習・全資格の合算

    func testStreakCountsFromYesterdayWhenTodayIsEmpty() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let d = { (n: Int) in cal.date(byAdding: .day, value: -n, to: today)! }
        XCTAssertEqual(StudyStreak.count(days: [d(1), d(2), d(3)]), 3)       // 今日まだでも途切れない
        XCTAssertEqual(StudyStreak.count(days: [today, d(1), d(3)]), 3)      // 1日だけの休みは休息日（日数には数えない）
        XCTAssertEqual(StudyStreak.walk(days: [today, d(1), d(3)]).rests, [d(2)])
        XCTAssertEqual(StudyStreak.count(days: [today, d(3)]), 1)            // 2日続けて休むと切れる
        XCTAssertEqual(StudyStreak.count(days: [d(2), d(3)]), 2)             // 昨日が休息日なら今日まだでも続いている
        XCTAssertEqual(StudyStreak.count(days: [d(3), d(4)]), 0)             // 昨日も一昨日もしていなければ0
        XCTAssertEqual(StudyStreak.count(days: []), 0)
        // 休息日は7日に1日まで：d(2)とd(5)の2回休むと、2回目で切れる
        XCTAssertEqual(StudyStreak.count(days: [today, d(1), d(3), d(4), d(6)]), 4)
        // 8日空ければもう一度使える
        XCTAssertEqual(StudyStreak.count(days: Set([0, 1, 3, 4, 5, 6, 7, 8, 9, 10, 12].map(d))), 11)
    }

    func testLongestStreak() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let d = { (n: Int) in cal.date(byAdding: .day, value: -n, to: today)! }
        XCTAssertEqual(StudyStreak.longest(days: [d(10), d(9), d(8), d(7), d(2), d(1)]), 4)
        XCTAssertEqual(StudyStreak.longest(days: [d(10), d(9), d(7), d(6)]), 4)   // 1日の休息日をはさんでも続く
        XCTAssertEqual(StudyStreak.longest(days: []), 0)
    }

    func testMergeAddsSameDayAcrossExams() {
        let day = Calendar.current.startOfDay(for: .now)
        var a = DailyStudyRecord(day: day); a.questions = 5; a.correct = 4; a.estimatedMinutes = 6
        var b = DailyStudyRecord(day: day); b.questions = 3; b.correct = 1; b.lessonsCompleted = 1; b.estimatedMinutes = 4
        let merged = AllExamsActivity.merge([[day: a], [day: b]])
        XCTAssertEqual(merged[day]?.questions, 8)
        XCTAssertEqual(merged[day]?.correct, 5)
        XCTAssertEqual(merged[day]?.lessonsCompleted, 1)
        XCTAssertEqual(merged[day]?.estimatedMinutes, 10)
        XCTAssertEqual(merged[day]?.level, 2)        // 8問＋レッスン1(=5問分)＝13点
    }

    // MARK: - 途中セッションの保存

    func testQuizSessionRoundTripAndClearWhenFinished() {
        let defaults = UserDefaults(suiteName: "QuizSessionTest-\(UUID().uuidString)")!
        var s = QuizSession(title: "復習 5問", questionIds: ["a", "b", "c"], index: 1,
                            selectedByIndex: [0: [2], 1: [0, 3]], submittedIndices: [0],
                            resultByIndex: [0: true], hintLevelByIndex: [1: 2], hintTextByIndex: [1: "着眼点"],
                            eliminatedByIndex: [1: [1]], hintUsedIndices: [1], savedAt: .now)
        XCTAssertEqual(s.remaining, 2)
        QuizSessionStore.save(s, examKey: "itp", defaults: defaults)
        XCTAssertEqual(QuizSessionStore.load(examKey: "itp", defaults: defaults), s)
        XCTAssertNil(QuizSessionStore.load(examKey: "fe", defaults: defaults))      // 資格ごとに別
        // 全問答え合わせ済みのものは読み込まず、消す
        s.submittedIndices = [0, 1, 2]
        QuizSessionStore.save(s, examKey: "itp", defaults: defaults)
        XCTAssertNil(QuizSessionStore.load(examKey: "itp", defaults: defaults))
        XCTAssertNil(defaults.data(forKey: "quizSession.itp"))
    }

    // MARK: - 聞き流し

    func testListeningScriptReadsAnswerContentAndShortExplanation() {
        let q = QuizQuestion(id: "t1", question: "PDCAのCは何ですか。", choices: ["計画", "評価", "実行", "改善"],
                             correctAnswers: [1], explanation: "Cは評価です。Checkの略です。3文目は読みません。",
                             source: nil, wrongChoiceExplanations: [:], domain: ExamDomain.allCases[0],
                             service: "", difficulty: 1, tags: [], beginnerNote: nil)
        let p = ListeningScript.parts(for: q, readChoices: true, number: 1)
        XCTAssertEqual(p.question, "では、第1問。PDCAのCは何ですか。")
        XCTAssertEqual(p.choices, ["1つ目、計画。", "2つ目、評価。", "3つ目、実行。", "4つ目、改善。"])
        XCTAssertEqual(p.answer, "正解は、2番の、評価、です。")      // 番号だけでなく中身まで読む
        XCTAssertEqual(p.explanation, "Cは評価です。Checkの略です。")  // 解説は2文まで
        XCTAssertTrue(ListeningScript.parts(for: q, readChoices: false).choices.isEmpty)
        XCTAssertEqual(ListeningScript.parts(for: q, readChoices: false, number: 2).question, "第2問。PDCAのCは何ですか。")
    }

    func testListeningProgressRoundTrip() {
        let defaults = UserDefaults(suiteName: "ListeningTest-\(UUID().uuidString)")!
        var p = ListeningProgress()
        p.completedChapterIds = ["a-1"]; p.heardIds = ["q1"]; p.lastChapterId = "a-2"; p.lastIndex = 3
        p.save(examKey: "itp", defaults: defaults)
        XCTAssertEqual(ListeningProgress.load(examKey: "itp", defaults: defaults), p)
        XCTAssertEqual(ListeningProgress.load(examKey: "fe", defaults: defaults), ListeningProgress())
    }

    // MARK: - 学習リマインド

    private func jstCal() -> Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Tokyo")!; return c }
    private func at(_ cal: Calendar, _ d: Int, _ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 11, day: d, hour: h, minute: m))!
    }

    func testReminderIncludesTodayWhenNotStudiedAndBeforeTime() {
        let cal = jstCal()
        let dates = StudyReminder.fireDates(now: at(cal, 11, 9), hour: 20, minute: 0, studiedToday: false, days: 7, calendar: cal)
        XCTAssertEqual(dates.count, 7)
        XCTAssertEqual(dates.first, at(cal, 11, 20))
    }

    func testReminderSkipsTodayWhenAlreadyStudied() {
        let cal = jstCal()
        let dates = StudyReminder.fireDates(now: at(cal, 11, 9), hour: 20, minute: 0, studiedToday: true, days: 7, calendar: cal)
        XCTAssertEqual(dates.count, 6)
        XCTAssertEqual(dates.first, at(cal, 12, 20))   // 学習済みの日は鳴らさない
    }

    func testReminderSkipsTodayWhenTimeHasPassed() {
        let cal = jstCal()
        let dates = StudyReminder.fireDates(now: at(cal, 11, 21), hour: 20, minute: 0, studiedToday: false, days: 7, calendar: cal)
        XCTAssertEqual(dates.first, at(cal, 12, 20))
        XCTAssertEqual(StudyReminder.identifier(for: at(cal, 12, 20), calendar: cal), "study.reminder.2026-11-12")
    }

    // MARK: - 要確認の印

    func testQuestionFlagsToggleAndReport() {
        let defaults = UserDefaults(suiteName: "FlagTest-\(UUID().uuidString)")!
        XCTAssertTrue(QuestionFlags.toggle("q1", examKey: "itp", defaults: defaults))
        XCTAssertTrue(QuestionFlags.contains("q1", examKey: "itp", defaults: defaults))
        XCTAssertFalse(QuestionFlags.contains("q1", examKey: "fe", defaults: defaults))   // 資格ごとに分かれる
        XCTAssertFalse(QuestionFlags.toggle("q1", examKey: "itp", defaults: defaults))
        XCTAssertTrue(QuestionFlags.ids(examKey: "itp", defaults: defaults).isEmpty)
        let q = QuizQuestion(id: "q9", question: "テスト問題です", choices: ["a", "b"], correctAnswers: [0],
                             explanation: "", source: nil, wrongChoiceExplanations: [:], domain: ExamDomain.allCases[0],
                             service: "", difficulty: 1, tags: [], beginnerNote: nil)
        let text = QuestionFlags.reportText(examName: "ITパスポート", questions: [q])
        XCTAssertTrue(text.contains("q9：テスト問題です"))
        XCTAssertTrue(text.contains("ITパスポート・1問"))
    }
}
