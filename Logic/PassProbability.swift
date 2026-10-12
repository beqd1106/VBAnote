import Foundation

/// 合格可能性スコア（0〜100の「目安」）を算出する。
/// ※これは学習を促すための目安であり、合格を保証・予測するものではない。
///   UI 上でも必ず「目安」である旨を明記する。
///
/// 4つの要素を重み付けして合成する：
///   ① 分野別正答率（公式配点で加重）           … 50%
///   ② 直近の模擬試験スケールスコア（ExamInfo.passScore基準）   … 25%
///   ③ 復習の消化率（溜め込んでいないか）         … 15%
///   ④ 学習の継続（連続学習日数）                 … 10%
enum PassProbability {

    struct Inputs {
        /// 分野ごとの正答率（0〜1）。データが無い分野は0扱い。
        var correctRateByDomain: [ExamDomain: Double]
        /// 直近の模擬試験スコア（0〜1000）。未受験ならnil。
        var latestMockScaledScore: Int?
        /// 復習キューの消化率（0〜1）。期限切れが無ければ1。
        var reviewCompletionRate: Double
        /// 連続学習日数
        var studyStreak: Int
        /// これまでに回答した総問題数（学習量が少なすぎる場合の信頼度補正に使用）
        var totalAnswered: Int
    }

    /// 0〜100 の目安スコア
    static func score(_ input: Inputs) -> Int {
        // 1問も回答していなければ推定の根拠がないため0（「まずは毎日の学習から」）
        guard input.totalAnswered > 0 else { return 0 }

        // ① 配点加重の正答率
        var weighted = 0.0
        for domain in ExamDomain.allCases {
            let rate = input.correctRateByDomain[domain] ?? 0
            weighted += rate * domain.weight
        }
        let domainComponent = weighted * 50.0   // 0〜50

        // ② 模擬試験スコア（合格ラインで満点、それ未満は比例）
        let mockComponent: Double
        if let s = input.latestMockScaledScore {
            mockComponent = min(1.0, Double(s) / Double(ExamInfo.passScore)) * 25.0
        } else {
            mockComponent = 0
        }

        // ③ 復習消化率
        let reviewComponent = min(1.0, max(0.0, input.reviewCompletionRate)) * 15.0

        // ④ 継続（14日で満点）
        let streakComponent = min(1.0, Double(input.studyStreak) / 14.0) * 10.0

        var total = domainComponent + mockComponent + reviewComponent + streakComponent

        // 学習量が少なすぎる場合は過信を避けるため上限を抑える
        if input.totalAnswered < 20 {
            total = min(total, 35)
        } else if input.totalAnswered < 50 {
            total = min(total, 60)
        }

        return Int(total.rounded())
    }

    /// スコアに応じた状態ラベル
    static func label(for score: Int) -> String {
        switch score {
        case 80...:  return "合格圏が見えています"
        case 60..<80: return "あと一歩。弱点を詰めましょう"
        case 40..<60: return "基礎固めを継続しましょう"
        default:      return "まずは毎日の学習から"
        }
    }
}
