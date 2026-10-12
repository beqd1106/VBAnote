import SwiftUI

/// 画面横断で再利用する共通UI部品。スタイルのばらつきを防ぐ。

// MARK: - カード容器

struct Card<Content: View>: View {
    var padding: CGFloat
    var content: Content

    init(padding: CGFloat = Theme.Space.l, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: Theme.cardShadow(), radius: 10, x: 0, y: 4)
    }
}

// MARK: - ボタン

struct PrimaryButton: View {
    let title: String
    var icon: String? = nil
    var enabled: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(enabled ? Theme.orange : Theme.inkSoft.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .disabled(!enabled)
    }
}

struct SecondaryButton: View {
    let title: String
    var icon: String? = nil
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                if let icon { Image(systemName: icon) }
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(Theme.blue)
            .background(Theme.blueSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
    }
}

// MARK: - チップ／タグ

struct DomainChip: View {
    let domain: ExamDomain
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: domain.systemIcon).font(.system(size: 11))
            Text(domain.shortTitle).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .foregroundStyle(domain.color)
        .background(domain.color.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct TagChip: View {
    let text: String
    var color: Color = Theme.inkSoft
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 9).padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.10))
            .clipShape(Capsule())
    }
}

// MARK: - 進捗バー

struct ProgressBar: View {
    /// 0〜1
    let value: Double
    var color: Color = Theme.blue
    var height: CGFloat = 10
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.line)
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: height)
    }
}

// MARK: - 円形スコアリング（合格可能性など）

struct ScoreRing: View {
    /// 0〜1
    let value: Double
    var color: Color = Theme.orange
    var lineWidth: CGFloat = 12
    var label: String
    var caption: String
    var body: some View {
        ZStack {
            Circle().stroke(Theme.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text(label).font(.system(size: 30, weight: .bold)).foregroundStyle(Theme.navy)
                Text(caption).font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            }
        }
    }
}

// MARK: - バッジ

struct BadgeView: View {
    let title: String
    let icon: String
    let earned: Bool
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(earned ? Theme.orangeSoft : Theme.line.opacity(0.5))
                    .frame(width: 56, height: 56)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(earned ? Theme.orange : Theme.inkSoft.opacity(0.5))
            }
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(earned ? Theme.ink : Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(width: 84)
        .opacity(earned ? 1 : 0.6)
    }
}

// MARK: - セクション見出し

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.navy)
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.blue)
            }
        }
    }
}

// MARK: - 空状態

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            Image(systemName: icon).font(.system(size: 40)).foregroundStyle(Theme.inkSoft.opacity(0.5))
            Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink)
            Text(message).font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Space.xxl)
    }
}

// MARK: - 背景

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            LinearGradient(colors: [Theme.orange.opacity(0.05), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        }
    }
}
