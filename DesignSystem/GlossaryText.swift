import SwiftUI

/// 本文中の専門用語（ハイパーバイザー・MFA・IAM 等）に下線を引き、
/// タップで「初心者向けの簡単な説明」をポップオーバー表示するテキスト。
/// Web版の glossify と同じ glossary.json（ContentRepository.glossary）を共有する。
///
/// 使い方：通常の `Text(body)` を `GlossaryText(text: body, ...)` に置き換えるだけ。
struct GlossaryText: View {
    let text: String
    var size: CGFloat = 15
    var weight: Font.Weight = .regular
    var color: Color = Theme.ink
    var lineSpacing: CGFloat = 3

    /// term.count 降順で保持済み（長い語を優先マッチ：「Amazon EC2」を「EC2」より先に拾う）
    private let entries = ContentRepository.shared.glossary
    @State private var selected: GlossaryEntry?

    var body: some View {
        Text(attributed)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(color)
            .lineSpacing(lineSpacing)
            .tint(Theme.blue)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "glossary",
                      let host = url.host,
                      let idx = Int(host), idx >= 0, idx < entries.count
                else { return .systemAction }
                selected = entries[idx]
                return .handled
            })
            .popover(item: $selected) { entry in
                GlossaryPopover(entry: entry)
                    .presentationCompactAdaptation(.popover)
            }
    }

    /// 用語を初回出現のみリンク化した AttributedString を組み立てる。
    /// Web版 glossify と同じ走査ロジック（境界判定つき・1語1回）。
    private var attributed: AttributedString {
        let chars = Array(text)
        let n = chars.count
        var result = AttributedString("")
        var used = Set<Int>()
        var i = 0

        func isAlnum(_ c: Character) -> Bool { c.isASCII && (c.isLetter || c.isNumber) }

        while i < n {
            var matched = false
            for (gi, e) in entries.enumerated() {
                if used.contains(gi) { continue }
                let key = Array(e.term)
                let kl = key.count
                guard kl > 0, i + kl <= n, Array(chars[i..<i+kl]) == key else { continue }
                let leftBad  = isAlnum(key[0])      && i > 0      && isAlnum(chars[i-1])
                let rightBad = isAlnum(key[kl-1])   && i + kl < n && isAlnum(chars[i+kl])
                if leftBad || rightBad { continue }

                var seg = AttributedString(e.term)
                seg.link = URL(string: "glossary://\(gi)")
                seg.underlineStyle = .single
                seg.foregroundColor = Theme.blue
                result.append(seg)
                used.insert(gi)
                i += kl
                matched = true
                break
            }
            if !matched {
                result.append(AttributedString(String(chars[i])))
                i += 1
            }
        }
        return result
    }
}

/// 用語の説明ポップオーバー（iPhoneでも `.presentationCompactAdaptation(.popover)` で吹き出し表示）
private struct GlossaryPopover: View {
    let entry: GlossaryEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.term)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.navy)
            Text(entry.explanation)
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: 280)
        .presentationBackground(Theme.card)
    }
}
