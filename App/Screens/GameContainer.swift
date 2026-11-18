import SwiftUI
import BrainCore

/// 全屏训练：依次进行 plan 里的玩法，每局后出结算
struct GameContainer: View {
    let plan: SessionPlan
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var phase: Phase = .playing
    @State private var runID = UUID()
    @State private var confirmQuit = false

    enum Phase {
        case playing
        case result(GameResult, SessionRecord)
    }

    private var mode: ModeID { plan.modes[min(index, plan.modes.count - 1)] }

    var body: some View {
        ZStack {
            InkBackground()
            switch phase {
            case .playing:
                VStack(spacing: 0) {
                    GameTopBar(mode: mode, level: model.progress.level(for: mode),
                               step: plan.modes.count > 1 ? "\(index + 1)/\(plan.modes.count)" : nil) {
                        confirmQuit = true
                    }
                    GameRouter(mode: mode, level: model.progress.level(for: mode)) { result in
                        finish(result)
                    }
                    .id(runID)
                }
                .transition(.opacity)
            case let .result(result, record):
                ResultView(result: result, record: record,
                           hasNext: index + 1 < plan.modes.count,
                           onNext: next, onRetry: retry, onClose: { dismiss() })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .alert("结束这次训练？", isPresented: $confirmQuit) {
            Button("继续练", role: .cancel) {}
            Button("结束", role: .destructive) { dismiss() }
        } message: {
            Text("这一局不会计入记录")
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
    }

    private func finish(_ result: GameResult) {
        let rec = model.record(result, mode: mode, daily: plan.isDaily)
        if rec.newLevel > rec.level { SFX.levelUp(); Haptic.success() }
        withAnimation(.easeInOut(duration: 0.35)) { phase = .result(result, rec) }
    }

    private func next() {
        index += 1
        runID = UUID()
        withAnimation(.easeInOut(duration: 0.3)) { phase = .playing }
    }

    private func retry() {
        runID = UUID()
        withAnimation(.easeInOut(duration: 0.3)) { phase = .playing }
    }
}

struct GameTopBar: View {
    let mode: ModeID
    let level: Int
    var step: String?
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Palette.muted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.ink.opacity(0.7)))
                    .overlay(Circle().stroke(Palette.line, lineWidth: 0.8))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(mode.kind.title).font(.song(16, .bold)).foregroundColor(Palette.cream)
                    Text("· \(mode.title)").font(.song(13)).foregroundColor(Palette.muted)
                }
                HStack(spacing: 6) {
                    LevelChip(level: level)
                    if let step { Text("每日 \(step)").font(.song(11)).foregroundColor(Palette.goldDeep) }
                }
            }
            Spacer()
            CitationTag(text: mode.kind.citation)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

struct GameRouter: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    var body: some View {
        switch mode.kind {
        case .schulte: SchulteGameView(mode: mode, level: level, onFinish: onFinish)
        case .stroop: StroopGameView(mode: mode, level: level, onFinish: onFinish)
        case .memory: MemoryGameView(mode: mode, level: level, onFinish: onFinish)
        case .digits: DigitsGameView(mode: mode, level: level, onFinish: onFinish)
        case .mirror:
            if mode == .mirrorRhythm {
                RhythmGameView(level: level, onFinish: onFinish)
            } else {
                MirrorGameView(mode: mode, level: level, onFinish: onFinish)
            }
        case .sorting: SortingGameView(mode: mode, level: level, onFinish: onFinish)
        case .story: StoryGameView(mode: mode, level: level, onFinish: onFinish)
        }
    }
}

struct ResultView: View {
    let result: GameResult
    let record: SessionRecord
    let hasNext: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void
    @State private var shownScore = 0
    @State private var appear = false

    private var levelText: String {
        if record.mode == .storyDelayed { return "延迟回忆不影响等级" }
        if record.newLevel > record.level { return "升级 Lv.\(record.level) → Lv.\(record.newLevel)" }
        if record.newLevel < record.level { return "下调 Lv.\(record.level) → Lv.\(record.newLevel)" }
        return "保持 Lv.\(record.level)"
    }

    var body: some View {
        ZStack {
            FloatingMotes(count: result.outcome == .fail ? 6 : 24)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer(minLength: 30)
                    Group {
                        if result.outcome == .fail { WrongMark(size: 86) } else { GoldCheck(size: 104) }
                    }
                    VStack(spacing: 8) {
                        Text(result.outcome.title)
                            .font(.song(30, .bold))
                            .foregroundStyle(result.outcome == .fail ? AnyShapeStyle(Palette.cream) : AnyShapeStyle(Palette.goldGradient))
                        Caption(result.headline, size: 15, weight: .regular, base: Palette.muted)
                            .padding(.horizontal, 24)
                    }
                    VStack(spacing: 4) {
                        Text("\(shownScore)")
                            .font(.digits(64, .bold))
                            .foregroundColor(Palette.cream)
                            .contentTransition(.numericText())
                        Text("得分").font(.song(12)).foregroundColor(Palette.muted)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: record.newLevel > record.level ? "arrow.up.circle.fill" :
                                (record.newLevel < record.level ? "arrow.down.circle" : "equal.circle"))
                        Text(levelText)
                        Text("· \(LevelSystem.rank(for: record.newLevel))")
                    }
                    .font(.song(14, .bold))
                    .foregroundColor(record.newLevel > record.level ? Palette.gold : Palette.muted)

                    VStack(spacing: 0) {
                        ForEach(Array(result.stats.enumerated()), id: \.offset) { i, s in
                            HStack {
                                Text(s.label).font(.song(14)).foregroundColor(Palette.muted)
                                Spacer()
                                Text(s.value).font(.song(15, .bold)).foregroundColor(Palette.cream)
                            }
                            .padding(.vertical, 11)
                            if i < result.stats.count - 1 { Rectangle().fill(Palette.line).frame(height: 0.6) }
                        }
                    }
                    .goldCard(padding: 16)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 12)

                    Caption(record.kind.benefit, size: 14, weight: .regular, base: Palette.faint)

                    VStack(spacing: 12) {
                        if hasNext {
                            Button("下一项", action: onNext).buttonStyle(GoldButtonStyle())
                        } else {
                            Button("再来一局", action: onRetry).buttonStyle(GoldButtonStyle())
                        }
                        HStack(spacing: 12) {
                            if hasNext { Button("再来一局", action: onRetry).buttonStyle(GhostButtonStyle()) }
                            Button("返回", action: onClose).buttonStyle(GhostButtonStyle())
                        }
                    }
                    .padding(.top, 4)
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 22)
            }
        }
        .task {
            withAnimation(.easeOut(duration: 0.5).delay(0.2)) { appear = true }
            let steps = 18
            for i in 1...steps {
                try? await Task.sleep(nanoseconds: 35_000_000)
                withAnimation(.easeOut(duration: 0.05)) { shownScore = result.score * i / steps }
            }
        }
    }
}

/// 结算数据格式化
enum Fmt {
    static func seconds(_ s: Double) -> String { String(format: "%.1f 秒", s) }
    static func ms(_ s: Double?) -> String { s.map { "\(Int(($0 * 1000).rounded())) 毫秒" } ?? "—" }
    static func percent(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
}
