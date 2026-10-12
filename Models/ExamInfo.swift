import Foundation

/// 資格ごとに変わる値をここに集約する（configs.py から生成。手で編集しない）。
enum ExamInfo {
    static let appName = "VBAnote"
    /// ホームのワードマークで強調する頭文字（例："FE"note）
    static let brandPrefix = "VBA"
    static let examShortName = "VBAエキスパート ベーシック"
    static let examFullName = "VBAエキスパート「Excel VBA ベーシック」"
    static let officialSite = "VBAエキスパート公式サイト（vbae.odyssey-com.co.jp）"
    static let organizerNotice = "「VBAエキスパート」は株式会社オデッセイ コミュニケーションズが実施する試験です。Microsoft・Excel は米国 Microsoft Corporation の商標です。本アプリは非公式の学習支援アプリです。"
    /// 本番模試の問題数と制限時間
    static let mockCount = 40
    static let mockMinutes = 50
    /// 合格ライン（1000点満点＝正答率×1000）
    static let passScore = 700
    static let mockNote = "本番は40問前後・50分・CBT（選択肢／ドロップダウン／穴埋め記述）で、合格基準は1000点満点中700点以上（問題更新により変動あり）。この模試は4択形式です。2027年4月に出題範囲のリニューアルが予定されています（2027年3月末までは現行試験）。最新は公式サイトでご確認ください。"
    static let servicesTitle = "頻出コード・キーワード一覧"
    static let servicesSubtitle = "プロパティ・メソッド・関数をカテゴリ別に確認"
    static let servicesSearchPlaceholder = "コード・キーワードを検索"

    struct NextCert { let title: String; let subtitle: String }
    static let nextCerts: [NextCert] = [
        .init(title: "VBAエキスパート Excel VBA スタンダード", subtitle: "配列・ユーザー定義関数・エラー処理まで"),
        .init(title: "MOS Excel Expert", subtitle: "Excelの上級機能を証明"),
        .init(title: "RPA技術者検定", subtitle: "業務自動化の基礎を証明"),
    ]

    /// 直前チェックリスト
    static let finalChecklist: [String] = [
        "マクロ有効ブック（.xlsm）と個人用マクロブックの違いを言える",
        "マクロの記録で記録されない操作・相対参照の記録を説明できる",
        "Sub プロシージャの書き方とコメント（'）・行継続（ _）を書ける",
        "オブジェクト.プロパティ と オブジェクト.メソッド 引数 の書き方を区別できる",
        "Dim・Option Explicit・主なデータ型（Long・String・Date・Variant）を言える",
        "変数の適用範囲（プロシージャ・モジュール・Public）と Const を区別できる",
        "Range と Cells の指定方法、Offset・Resize・End(xlUp) を使える",
        "If…Then…ElseIf…Else と For…Next（Step・Exit For）と With を読める",
        "Left・Mid・InStr・Format・DateSerial・MsgBox・InputBox の戻り値を言える",
        "Workbooks.Open・SaveAs・Close と Worksheets.Add・Copy・Delete を書ける",
        "受験会場・試験時間（50分）・CBTの操作方法を確認した",
    ]

    /// 直前に見直す重要用語カードのID（terms.json の t-key1〜6）
    static let keyTermIds = ["t-key1", "t-key2", "t-key3", "t-key4", "t-key5", "t-key6"]

    /// 完全初心者向け 8週間の標準ロードマップ
    static let roadmap: [WeekGoal] = [
        .init(week: 1, title: "マクロとVBAの基本", detail: "VBEの画面／マクロの記録／個人用マクロブック／セキュリティ設定", domains: [.concept]),
        .init(week: 2, title: "モジュールと構文", detail: "Subプロシージャ／コメント／オブジェクト・プロパティ・メソッド／演算子", domains: [.syntax]),
        .init(week: 3, title: "変数と定数", detail: "Dim と Option Explicit／データ型／適用範囲／Const と組み込み定数", domains: [.variable]),
        .init(week: 4, title: "セルの操作", detail: "Range と Cells／Value と NumberFormat／Offset・Resize・Copy／最終行の取得", domains: [.cell]),
        .init(week: 5, title: "条件分岐と繰り返し", detail: "If…ElseIf…Else／For…Next と Step／With／ループの回数", domains: [.control]),
        .init(week: 6, title: "関数とダイアログ", detail: "文字列・日付・数値の関数／MsgBox と InputBox／型変換", domains: [.control]),
        .init(week: 7, title: "ブックとシート", detail: "Open・SaveAs・Close／ThisWorkbook と ActiveWorkbook／シートの追加・コピー・削除", domains: [.book, .concept]),
        .init(week: 8, title: "模擬試験と直前対策", detail: "全分野横断の模試→間違えたコードの読み直し→頻出キーワードの総仕上げ", domains: ExamDomain.allCases),
    ]
}
