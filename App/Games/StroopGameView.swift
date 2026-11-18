import SwiftUI
import BrainCore

struct StroopGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @Environment(AppModel.self) private var model
    @State private var config: StroopConfig
    @State private var trials: [StroopTrial]
    @State private var current = 0
    @State private var responses: [StroopResponse] = []
    @State private var trialStart = Date()
    @State private var sessionStart = Date()
    @State private var ready = false
    @State private var finished = false
    @State private var timeoutTask: Task<Void, Never>?
    @State private var buttonOrder: [Int]
    @State private var rng: SeededRNG
    @State private var lastFeedback: Bool?
    @State private var voice: VoiceAnswer?
    @State private var heard = ""
    @State private var voiceOn = false

    private let pageSize = 12

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        var r = SeededRNG.random()
        let c = StroopConfig(mode: mode, level: level)
        _config = State(initialValue: c)
        _trials = State(initialValue: StroopGenerator.trials(config: c, rng: &r))
        _buttonOrder = State(initialValue: Array(0..<c.buttonCount))
        _rng = State(initialValue: r)
    }

    private var usesGrid: Bool { mode == .stroopColor || mode == .stroopSwitch }
    private var canUseVoice: Bool { usesGrid && model.settings.voiceAnswer }

    var body: some View {
        ZStack {
            VStack(spacing: 14) {
                instructionBar
                if usesGrid { gridStage } else { singleStage }
                Spacer(minLength: 0)
                if voiceOn { voiceBar }
                answerButtons
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 18)

            if !ready {
                ReadyOverlay(subtitle: readySubtitle) { begin() }
            }
        }
        .onDisappear {
            timeoutTask?.cancel()
            voice?.stop()
        }
    }

    private var readySubtitle: String {
        switch mode {
        case .stroopSwitch: return "[金框]说颜色，[白色虚线框]读字"
        case .stroopCount: return "回答[有几个]数字，不是数字是几"
        case .stroopDirection: return "回答字[出现在哪边]，不管字写的是什么"
        default: return canUseVoice ? "看金框里字的颜色，[大声说出来]" : "看金框里字的[颜色]，点对应按钮"
        }
    }

    private var instructionBar: some View {
        HStack {
            Text(barText).font(.song(15, .bold)).foregroundColor(Palette.cream)
            Spacer()
            Text("\(min(current + 1, trials.count))/\(trials.count)")
                .font(.digits(14, .bold)).foregroundColor(Palette.muted)
        }
        .overlay(alignment: .bottom) {
            TimelineView(.periodic(from: .now, by: 0.05)) { ctx in
                let f = ready && !finished ? 1 - ctx.date.timeIntervalSince(trialStart) / config.itemTime : 1
                GoldBar(fraction: f, height: 2).offset(y: 10)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private var barText: String {
        switch mode {
        case .stroopSwitch: return "跟着框，金框说颜色 · 白框读字"
        case .stroopCount: return "有几个数字？"
        case .stroopDirection: return "字在哪个方位？"
        default: return "跟着金框，说出颜色"
        }
    }

    // MARK: 网格（视频同款 3×4）

    private var gridStage: some View {
        let page = current / pageSize
        let start = page * pageSize
        let end = min(start + pageSize, trials.count)
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(start..<end, id: \.self) { i in
                gridCell(i)
            }
        }
        .padding(.top, 6)
        .animation(.easeInOut(duration: 0.18), value: current)
    }

    private func gridCell(_ i: Int) -> some View {
        let t = trials[i]
        let isCurrent = i == current && ready && !finished
        let isDone = i < current
        let resp = i < responses.count ? responses[i] : nil
        var word = InkColor.red, ink = InkColor.red, cue = StroopCue.color
        if case let .colorWord(w, k, c) = t.stimulus { word = w; ink = k; cue = c }
        return ZStack {
            RoundedRectangle(cornerRadius: 10).fill(Palette.card)
            if isCurrent {
                if cue == .color {
                    RoundedRectangle(cornerRadius: 10).stroke(Palette.gold, lineWidth: 2.2)
                        .shadow(color: Palette.gold.opacity(0.7), radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Palette.cream, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
            } else {
                RoundedRectangle(cornerRadius: 10).stroke(Palette.line, lineWidth: 0.8)
            }
            VStack(spacing: 2) {
                Text(word.name)
                    .font(.song(36, .bold))
                    .foregroundColor(Palette.inkColor(ink))
                if isDone, let resp {
                    Text(cue == .color ? ink.name : word.name)
                        .font(.song(9))
                        .foregroundColor(resp.correct ? Palette.muted : Palette.red)
                }
            }
        }
        .frame(height: 96)
        .opacity(isDone ? 0.38 : 1)
        .scaleEffect(isCurrent ? 1.04 : 1)
    }

    // MARK: 单题（数个数 / 辨方位）

    private var singleStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Palette.card.opacity(0.85))
            RoundedRectangle(cornerRadius: 18).stroke(Palette.line, lineWidth: 0.8)
            if current < trials.count && ready {
                switch trials[current].stimulus {
                case let .count(digit, count):
                    HStack(spacing: 14) {
                        ForEach(0..<count, id: \.self) { _ in
                            Text("\(digit)").font(.digits(54, .bold)).foregroundColor(Palette.cream)
                        }
                    }
                    .id(current)
                    .transition(.opacity)
                case let .direction(word, position):
                    directionStimulus(word: word, position: position)
                        .id(current)
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }
            if let fb = lastFeedback {
                Circle().stroke(fb ? Palette.gold : Palette.red, lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(14)
            }
        }
        .frame(height: 300)
        .padding(.top, 8)
    }

    private func directionStimulus(word: Direction4, position: Direction4) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let p: CGPoint = {
                switch position {
                case .up: return CGPoint(x: w / 2, y: h * 0.17)
                case .down: return CGPoint(x: w / 2, y: h * 0.83)
                case .left: return CGPoint(x: w * 0.17, y: h / 2)
                case .right: return CGPoint(x: w * 0.83, y: h / 2)
                }
            }()
            ZStack {
                Circle().fill(Palette.gold.opacity(0.6)).frame(width: 6, height: 6).position(x: w / 2, y: h / 2)
                Text(word.name)
                    .font(.song(44, .bold))
                    .foregroundColor(Palette.cream)
                    .position(p)
            }
        }
    }

    // MARK: 按钮

    private var answerButtons: some View {
        let n = config.buttonCount
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: n == 6 ? 3 : n)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(buttonOrder, id: \.self) { idx in
                Button { answer(idx) } label: { buttonLabel(idx) }
                    .buttonStyle(PressStyle())
                    .disabled(!ready || finished)
            }
        }
        .opacity(voiceOn ? 0.55 : 1)
    }

    @ViewBuilder
    private func buttonLabel(_ idx: Int) -> some View {
        switch mode {
        case .stroopCount:
            Text("\(idx + 1)")
                .font(.digits(26, .bold))
                .foregroundColor(Palette.cream)
                .frame(maxWidth: .infinity).frame(height: 62)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardHi))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.lineHi, lineWidth: 0.8))
        case .stroopDirection:
            let d = Direction4(rawValue: idx) ?? .up
            Image(systemName: d.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Palette.gold)
                .frame(maxWidth: .infinity).frame(height: 62)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cardHi))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.lineHi, lineWidth: 0.8))
        default:
            let c = config.colors[idx]
            Text(c.name)
                .font(.song(config.buttonCount >= 5 ? 19 : 22, .bold))
                .foregroundColor(Palette.cream)
                .frame(maxWidth: .infinity).frame(height: 58)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.inkColor(c).opacity(0.85)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
        }
    }

    private var voiceBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill").foregroundColor(Palette.gold)
            Text(heard.isEmpty ? "正在听……说出颜色" : "听到：\(heard)")
                .font(.song(13)).foregroundColor(Palette.muted).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Capsule().fill(Palette.ink.opacity(0.7)))
        .overlay(Capsule().stroke(Palette.line, lineWidth: 0.8))
    }

    // MARK: 流程

    private func begin() {
        withAnimation { ready = true }
        sessionStart = Date()
        trialStart = Date()
        if config.shuffleButtons { buttonOrder.shuffle(using: &rng) }
        scheduleTimeout()
        if canUseVoice {
            let v = VoiceAnswer()
            v.colors = config.colors
            v.onColor = { c in
                if let idx = config.colors.firstIndex(of: c) { answer(idx) }
            }
            v.onHeard = { heard = $0 }
            VoiceAnswer.requestPermission { ok in
                if ok && v.begin() {
                    voice = v
                    voiceOn = true
                }
            }
        }
    }

    private func answer(_ idx: Int) {
        guard ready, !finished, current < trials.count else { return }
        let t = trials[current]
        let rt = Date().timeIntervalSince(trialStart)
        let ok = idx == t.answer
        responses.append(StroopResponse(trial: t, correct: ok, rt: rt))
        if ok { Haptic.tap(); SFX.tick() } else { Haptic.error() }
        lastFeedback = ok
        advance()
    }

    private func advance() {
        current += 1
        if current >= trials.count {
            finish()
            return
        }
        trialStart = Date()
        if config.shuffleButtons && current % pageSize == 0 {
            withAnimation(.easeInOut(duration: 0.25)) { buttonOrder.shuffle(using: &rng) }
        }
        scheduleTimeout()
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        let index = current
        let wait = UInt64(config.itemTime * 1_000_000_000)
        timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: wait)
            guard !Task.isCancelled, !finished, current == index else { return }
            responses.append(StroopResponse(trial: trials[index], correct: false, rt: nil))
            Haptic.soft()
            lastFeedback = false
            advance()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        timeoutTask?.cancel()
        voice?.stop()
        voiceOn = false
        let s = StroopScorer.evaluate(responses, config: config)
        var stats = [
            StatLine(label: "正确率", value: Fmt.percent(s.accuracy)),
            StatLine(label: "平均反应", value: Fmt.ms(s.meanRT)),
            StatLine(label: "超时", value: "\(s.timeouts) 题"),
            StatLine(label: "每题限时", value: Fmt.seconds(config.itemTime))
        ]
        if let inter = s.interferenceMs {
            stats.insert(StatLine(label: "干扰代价", value: "\(inter) 毫秒"), at: 2)
        }
        if let sw = s.switchCostMs {
            stats.insert(StatLine(label: "切换代价", value: "\(sw) 毫秒"), at: 2)
        }
        let headline: String
        switch s.outcome {
        case .excellent: headline = "又快又准，大脑的[刹车]很灵"
        case .pass: headline = "那半秒的犹豫，正在[变短]"
        case .fail: headline = "不读字，只看[颜色]——慢一点也没关系"
        }
        onFinish(GameResult(score: s.score, outcome: s.outcome, accuracy: s.accuracy, meanRT: s.meanRT,
                            duration: Date().timeIntervalSince(sessionStart), headline: headline, stats: stats))
    }
}
