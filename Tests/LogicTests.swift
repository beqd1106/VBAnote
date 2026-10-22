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
                     explanation: "解説", wrongChoiceExplanations: [:],
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
}
