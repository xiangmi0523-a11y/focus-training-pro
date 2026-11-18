import SwiftUI
import UIKit
import BrainCore

/// 字幕：方括号里的字金色高亮，如 "从[1]开始"
struct Caption: View {
    let text: String
    var size: CGFloat = 17
    var weight: Font.SongWeight = .bold
    var base: Color = Palette.cream
    var highlight: Color = Palette.gold

    init(_ text: String, size: CGFloat = 17, weight: Font.SongWeight = .bold,
         base: Color = Palette.cream, highlight: Color = Palette.gold) {
        self.text = text
        self.size = size
        self.weight = weight
        self.base = base
        self.highlight = highlight
    }

    var body: some View {
        Caption.styled(text, base: base, highlight: highlight)
            .font(.song(size, weight))
            .multilineTextAlignment(.center)
            .lineSpacing(4)
    }

    static func styled(_ text: String, base: Color, highlight: Color) -> Text {
        var result = Text("")
        var buffer = ""
        var inside = false
        func flush() {
            guard !buffer.isEmpty else { return }
            result = result + Text(buffer).foregroundColor(inside ? highlight : base)
            buffer = ""
        }
        for ch in text {
            if ch == "[" { flush(); inside = true } else if ch == "]" { flush(); inside = false } else { buffer.append(ch) }
        }
        flush()
        return result
    }

    static func plain(_ text: String) -> String {
        text.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
    }
}

/// 视频右上角的研究出处小标签
struct CitationTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.song(10))
            .foregroundColor(Palette.muted)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 3).fill(Palette.ink.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Palette.line, lineWidth: 0.8))
    }
}

struct GoldButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.song(compact ? 15 : 18, .bold))
            .foregroundColor(Palette.ink)
            .padding(.horizontal, compact ? 18 : 28)
            .padding(.vertical, compact ? 10 : 15)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(
                Capsule().fill(Palette.goldGradient)
                    .shadow(color: Palette.gold.opacity(configuration.isPressed ? 0.15 : 0.35), radius: 14, y: 4)
            )
            .overlay(Capsule().stroke(Palette.goldBright.opacity(0.6), lineWidth: 0.8))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.song(compact ? 14 : 16, .bold))
            .foregroundColor(Palette.gold)
            .padding(.horizontal, compact ? 16 : 24)
            .padding(.vertical, compact ? 9 : 13)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(Capsule().fill(Palette.ink.opacity(configuration.isPressed ? 0.9 : 0.5)))
            .overlay(Capsule().stroke(Palette.goldDeep.opacity(0.8), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// 按下缩放的通用样式
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct GoldCard: ViewModifier {
    var padding: CGFloat = 16
    var highlight = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Palette.cardHi.opacity(0.92), Palette.card.opacity(0.92)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highlight ? Palette.gold.opacity(0.85) : Palette.line, lineWidth: highlight ? 1.2 : 0.8)
            )
            .shadow(color: highlight ? Palette.gold.opacity(0.18) : .black.opacity(0.25), radius: highlight ? 14 : 8, y: 3)
    }
}

extension View {
    func goldCard(padding: CGFloat = 16, highlight: Bool = false) -> some View {
        modifier(GoldCard(padding: padding, highlight: highlight))
    }
}

/// 视频里的圆环倒计时：细金环 + 刻度点 + 中间数字
struct RingTimer: View {
    /// 剩余比例 0...1
    let fraction: Double
    let label: String
    var unit: String = "秒"
    var size: CGFloat = 96
    var warning = false

    var body: some View {
        ZStack {
            Circle().stroke(Palette.line, lineWidth: 2)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, fraction)))
                .stroke(warning ? Palette.red : Palette.gold, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: (warning ? Palette.red : Palette.gold).opacity(0.5), radius: 6)
            ForEach(0..<12, id: \.self) { i in
                Circle()
                    .fill(Palette.goldDeep.opacity(i % 3 == 0 ? 0.9 : 0.35))
                    .frame(width: i % 3 == 0 ? 4 : 2.5, height: i % 3 == 0 ? 4 : 2.5)
                    .offset(y: -size / 2 - 7)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            VStack(spacing: 0) {
                Text(label)
                    .font(.digits(size * 0.34, .semibold))
                    .foregroundColor(warning ? Palette.red : Palette.cream)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit).font(.song(size * 0.12)).foregroundColor(Palette.muted)
                }
            }
        }
        .frame(width: size, height: size)
        .padding(8)
    }
}

/// 大对勾（过关）
struct GoldCheck: View {
    var size: CGFloat = 110
    @State private var progress: CGFloat = 0
    @State private var ring: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: ring)
                .stroke(Palette.gold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Circle().fill(Palette.gold.opacity(0.08))
            Path { p in
                p.move(to: CGPoint(x: size * 0.28, y: size * 0.52))
                p.addLine(to: CGPoint(x: size * 0.44, y: size * 0.67))
                p.addLine(to: CGPoint(x: size * 0.73, y: size * 0.36))
            }
            .trim(from: 0, to: progress)
            .stroke(Palette.goldBright, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .shadow(color: Palette.gold.opacity(0.55), radius: 18)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { ring = 1 }
            withAnimation(.easeOut(duration: 0.35).delay(0.3)) { progress = 1 }
        }
    }
}

struct WrongMark: View {
    var size: CGFloat = 90

    var body: some View {
        ZStack {
            Circle().stroke(Palette.red.opacity(0.8), lineWidth: 3)
            Image(systemName: "xmark").font(.system(size: size * 0.4, weight: .semibold)).foregroundColor(Palette.red)
        }
        .frame(width: size, height: size)
    }
}

struct LevelChip: View {
    let level: Int
    var showRank = true

    var body: some View {
        HStack(spacing: 4) {
            Text("Lv.\(level)").font(.digits(12, .bold))
            if showRank { Text(LevelSystem.rank(for: level)).font(.song(11, .bold)) }
        }
        .foregroundColor(Palette.ink)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Palette.goldGradient))
    }
}

struct RuleChip: View {
    let text: String
    var active = true

    var body: some View {
        Text(text)
            .font(.song(12, .bold))
            .foregroundColor(active ? Palette.gold : Palette.faint)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Palette.ink.opacity(0.7)))
            .overlay(Capsule().stroke(active ? Palette.gold.opacity(0.8) : Palette.line, lineWidth: 1))
    }
}

/// 细进度条
struct GoldBar: View {
    let fraction: Double
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.line.opacity(0.7))
                Capsule().fill(Palette.goldGradient)
                    .frame(width: max(height, geo.size.width * max(0, min(1, fraction))))
                    .shadow(color: Palette.gold.opacity(0.5), radius: 4)
            }
        }
        .frame(height: height)
    }
}

/// 「准备好了吗？」→「开始！」
struct ReadyOverlay: View {
    var subtitle: String?
    let onDone: () -> Void
    @State private var step = 0

    var body: some View {
        ZStack {
            Palette.ink.opacity(0.78).ignoresSafeArea()
            VStack(spacing: 18) {
                if step == 0 {
                    Caption("准备好了吗？", size: 26)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    if let subtitle {
                        Caption(subtitle, size: 15, weight: .regular, base: Palette.muted)
                            .padding(.horizontal, 32)
                    }
                } else {
                    Text("开始")
                        .font(.song(64, .bold))
                        .foregroundStyle(Palette.goldGradient)
                        .shadow(color: Palette.gold.opacity(0.6), radius: 18)
                        .transition(.scale(scale: 1.3).combined(with: .opacity))
                }
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            withAnimation(.easeOut(duration: 0.25)) { step = 1 }
            Haptic.soft()
            try? await Task.sleep(nanoseconds: 650_000_000)
            onDone()
        }
    }
}

/// SF Symbol 物品图标（找不到符号时用方块兜底）
struct SymbolIcon: View {
    let name: String
    var color: Color = Palette.gold
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: UIImage(systemName: name) != nil ? name : "square.fill")
            .font(.system(size: size, weight: .regular))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
    }
}

struct ItemTile: View {
    let item: ObjectItem
    var size: CGFloat = 64
    var showName = true
    var index: Int?
    var state: TileState = .normal

    enum TileState { case normal, selected, correct, wrong, dimmed }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Palette.card)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: state == .normal ? 0.8 : 1.6))
                SymbolIcon(name: item.symbol, color: Palette.hue(item.hue), size: size * 0.42)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let index {
                    Text("\(index)").font(.digits(9, .bold)).foregroundColor(Palette.muted).padding(5)
                }
                if state == .correct {
                    Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundColor(Palette.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing).padding(5)
                }
            }
            .frame(width: size, height: size)
            .opacity(state == .dimmed ? 0.35 : 1)
            if showName {
                Text(item.name).font(.song(11)).foregroundColor(Palette.muted).lineLimit(1)
            }
        }
    }

    private var borderColor: Color {
        switch state {
        case .normal, .dimmed: return Palette.line
        case .selected: return Palette.gold
        case .correct: return Palette.gold
        case .wrong: return Palette.red
        }
    }
}

/// 虚线占位格
struct DashedSlot: View {
    var size: CGFloat = 44
    var index: Int?
    var filled = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .stroke(filled ? Palette.goldDeep : Palette.lineHi, style: StrokeStyle(lineWidth: 1, dash: filled ? [] : [4, 3]))
            if let index {
                Text("\(index)").font(.digits(8, .bold)).foregroundColor(Palette.faint).padding(4)
            }
        }
        .frame(width: size, height: size)
    }
}

/// 页面顶部的小标题
struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title).font(.song(15, .bold)).foregroundColor(Palette.cream)
            Rectangle().fill(Palette.line).frame(height: 0.8)
            if let trailing { Text(trailing).font(.song(12)).foregroundColor(Palette.muted) }
        }
    }
}
