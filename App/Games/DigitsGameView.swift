import SwiftUI
import BrainCore

struct DigitsGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @Environment(AppModel.self) private var model
    @State private var config: DigitConfig
    @State private var rng: SeededRNG
    @State private var audio = DigitAudio()
    @State private var phase: Phase = .ready
    @State private var trial = 0
    @State private var sequence: [Int] = []
    @State private var input: [Int] = []
    @State private var activeDigit = -1
    @State private var exact = 0
    @State private var accuracies: [Double] = []
    @State private var lastCorrect: Bool?
    @State private var start = Date()
    @State private var warmed = false

    enum Phase { case ready, listening, input, feedback }

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        _config = State(initialValue: DigitConfig(mode: mode, level: level))
        _rng = State(initialValue: SeededRNG.random())
    }

    private var rate: Float {
        Float(model.settings.speechRate) + (config.speechRate - 0.5)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                HStack {
                    Text("第 \(min(trial + 1, config.trials))/\(config.trials) 组 · \(config.length) 位")
                        .font(.song(14, .bold)).foregroundColor(Palette.cream)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<config.trials, id: \.self) { i in
                            Circle()
                                .fill(i < accuracies.count ? (accuracies[i] >= 0.999 ? Palette.gold : Palette.red) : Palette.line)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.top, 6)
                listenerScene
                    .frame(height: phase == .input || phase == .feedback ? 170 : 330)
                    .animation(.easeInOut(duration: 0.35), value: phase)
                Caption(taskCaption, size: 16)
                    .frame(minHeight: 44)
                slots
                Spacer(minLength: 0)
                if phase == .input { keypad.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 16)

            if phase == .ready {
                ReadyOverlay(subtitle: readyText) { begin() }
            }
        }
        .task {
            await audio.warmUp(rate: rate)
            warmed = true
        }
        .onDisappear { audio.shutdown() }
    }

    private var readyText: String {
        switch mode {
        case .digitsBackward: return "戴上耳机效果更好 · 听完[倒着]输入"
        case .digitsSorted: return "听完把数字[从小到大]排好再输入"
        case .digitsCocktail: return "两个声音同时报数，只记[高音]那个"
        default: return "戴上耳机效果更好 · 背景再吵，记住[数字和顺序]"
        }
    }

    private var taskCaption: String {
        switch phase {
        case .ready, .listening:
            return mode == .digitsCocktail ? "只听[高音]，低沉的声音是干扰" : "仔细听，记住[数字和顺序]"
        case .input:
            switch mode {
            case .digitsBackward: return "现在，[倒着]复述一遍"
            case .digitsSorted: return "现在，[从小到大]输入"
            default: return "现在，[复述]一遍"
            }
        case .feedback:
            return lastCorrect == true ? "[全对]，再长一位也没问题" : "正确答案在上面，[对照]一下"
        }
    }

    // MARK: 场景：戴耳机的人 + 嘈杂人群 + 声波

    private var listenerScene: some View {
        ZStack {
            HStack(spacing: 26) {
                ForEach(0..<6, id: \.self) { i in
                    VStack(spacing: 2) {
                        Image(systemName: "ellipsis.bubble.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Palette.ink3)
                            .offset(x: i % 2 == 0 ? 6 : -6)
                        Image(systemName: "person.fill")
                            .font(.system(size: 34))
                            .foregroundColor(Palette.ink3.opacity(0.9))
                    }
                    .offset(y: CGFloat((i * 17) % 22))
                    .opacity(phase == .listening ? 1 : 0.5)
                }
            }
            .offset(y: 60)

            VStack(spacing: 18) {
                WaveLine(active: phase == .listening, highlight: activeDigit, count: sequence.count)
                    .frame(height: 60)
                ZStack {
                    Circle().fill(Palette.gold.opacity(phase == .listening ? 0.18 : 0.06)).frame(width: 110, height: 110)
                        .blur(radius: 10)
                    Image(systemName: "person.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(LinearGradient(colors: [Palette.blue, Color(hex: 0x3A5A82)], startPoint: .top, endPoint: .bottom))
                        .offset(y: 6)
                    Image(systemName: "headphones")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(Palette.goldGradient)
                        .offset(y: -14)
                }
                .frame(height: 110)
                .scaleEffect(phase == .input || phase == .feedback ? 0.75 : 1)
            }
        }
        .clipped()
    }

    private var slots: some View {
        let expected = DigitGenerator.expected(sequence, mode: mode)
        let perRow = min(max(config.length, 1), 7)
        let cols = Array(repeating: GridItem(.fixed(40), spacing: 6), count: perRow)
        return VStack(spacing: 10) {
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(0..<config.length, id: \.self) { i in
                    let v = i < input.count ? input[i] : nil
                    let correct = phase == .feedback && i < expected.count ? (v == expected[i]) : nil
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(v != nil ? (correct == false ? Palette.red : Palette.goldDeep) : Palette.lineHi,
                                    style: StrokeStyle(lineWidth: 1, dash: v == nil ? [4, 3] : []))
                        if let v {
                            Text("\(v)").font(.digits(22, .bold))
                                .foregroundColor(correct == false ? Palette.red : Palette.cream)
                        }
                    }
                    .frame(width: 40, height: 48)
                }
            }
            if phase == .feedback {
                HStack(spacing: 6) {
                    Text("正确").font(.song(12)).foregroundColor(Palette.muted)
                    ForEach(Array(expected.enumerated()), id: \.offset) { _, d in
                        Text("\(d)").font(.digits(18, .bold)).foregroundColor(Palette.gold)
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var keypad: some View {
        let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "del", "0", "ok"]
        let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
        return LazyVGrid(columns: cols, spacing: 10) {
            ForEach(keys, id: \.self) { k in
                Button { press(k) } label: {
                    Group {
                        if k == "del" {
                            Image(systemName: "delete.left").font(.system(size: 20))
                        } else if k == "ok" {
                            Text("确认").font(.song(18, .bold))
                        } else {
                            Text(k).font(.digits(26, .semibold))
                        }
                    }
                    .foregroundColor(k == "ok" ? Palette.ink : Palette.cream)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(k == "ok" ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.cardHi)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.lineHi, lineWidth: 0.6))
                    .opacity(k == "ok" && input.count < config.length ? 0.45 : 1)
                }
                .buttonStyle(PressStyle())
            }
        }
    }

    // MARK: 流程

    private func begin() {
        start = Date()
        playTrial()
    }

    private func playTrial() {
        input = []
        lastCorrect = nil
        activeDigit = -1
        sequence = DigitGenerator.sequence(length: config.length, rng: &rng)
        let distractor = mode == .digitsCocktail ? DigitGenerator.distractor(for: sequence, rng: &rng) : nil
        withAnimation { phase = .listening }
        let seq = sequence
        let cfg = config
        let r = rate
        Task { @MainActor in
            while !warmed { try? await Task.sleep(nanoseconds: 100_000_000) }
            await audio.play(target: seq, distractor: distractor, interval: cfg.interval, noiseLevel: cfg.noise,
                             distractorVolume: cfg.distractorVolume, rate: r) { i in
                withAnimation(.easeOut(duration: 0.12)) { activeDigit = i }
            }
            activeDigit = -1
            withAnimation(.easeInOut(duration: 0.3)) { phase = .input }
        }
    }

    private func press(_ k: String) {
        guard phase == .input else { return }
        switch k {
        case "del":
            if !input.isEmpty { input.removeLast(); Haptic.soft() }
        case "ok":
            guard input.count == config.length else { Haptic.error(); return }
            submit()
        default:
            guard input.count < config.length, let d = Int(k) else { return }
            Haptic.tap()
            input.append(d)
            if input.count == config.length {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { if phase == .input { submit() } }
            }
        }
    }

    private func submit() {
        guard phase == .input else { return }
        let expected = DigitGenerator.expected(sequence, mode: mode)
        let acc = DigitGenerator.positionAccuracy(expected: expected, answer: input)
        accuracies.append(acc)
        let ok = acc >= 0.999
        if ok { exact += 1; Haptic.success(); SFX.correct() } else { Haptic.error() }
        lastCorrect = ok
        withAnimation { phase = .feedback }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            if trial + 1 >= config.trials {
                finish()
            } else {
                trial += 1
                playTrial()
            }
        }
    }

    private func finish() {
        let mean = accuracies.isEmpty ? 0 : accuracies.reduce(0, +) / Double(accuracies.count)
        let eval = DigitGenerator.evaluate(exact: exact, trials: config.trials, meanPositionAccuracy: mean)
        let headline: String
        switch eval.outcome {
        case .excellent: headline = "吵闹里也能[抓住想听的]"
        case .pass: headline = "大部分都抓住了，再[加一位]"
        case .fail: headline = "试着把数字[两两分组]来记"
        }
        var stats = [
            StatLine(label: "全对组数", value: "\(exact) / \(config.trials)"),
            StatLine(label: "位置正确率", value: Fmt.percent(mean)),
            StatLine(label: "位数", value: "\(config.length) 位"),
            StatLine(label: "背景噪音", value: Fmt.percent(config.noise))
        ]
        if mode == .digitsCocktail {
            stats.append(StatLine(label: "干扰声音量", value: Fmt.percent(config.distractorVolume)))
        }
        onFinish(GameResult(score: eval.score, outcome: eval.outcome, accuracy: mean, meanRT: nil,
                            duration: Date().timeIntervalSince(start), headline: headline, stats: stats))
    }
}

/// 视频里的声波线：一排细刻度，数字出现时对应位置变亮
struct WaveLine: View {
    let active: Bool
    let highlight: Int
    let count: Int

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !active)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate
                let bars = 64
                let w = size.width / CGFloat(bars)
                let mid = size.height / 2
                g.fill(Path(CGRect(x: 0, y: mid - 0.5, width: size.width, height: 1)), with: .color(Palette.goldDeep.opacity(0.6)))
                for i in 0..<bars {
                    let noise = active ? abs(sin(Double(i) * 1.7 + t * 9)) * 0.5 + abs(sin(Double(i) * 0.37 + t * 4)) * 0.5 : 0.15
                    var h = CGFloat(4 + noise * 14)
                    var color = Palette.goldDeep.opacity(0.55)
                    if count > 0 {
                        let slot = Int(Double(i) / Double(bars) * Double(count))
                        let center = Int((Double(slot) + 0.5) / Double(count) * Double(bars))
                        if i == center {
                            if slot == highlight { h = size.height * 0.95; color = Palette.goldBright } else if slot < highlight {
                                h = size.height * 0.45; color = Palette.gold.opacity(0.8)
                            }
                        }
                    }
                    let rect = CGRect(x: CGFloat(i) * w + w * 0.35, y: mid - h / 2, width: max(1.2, w * 0.3), height: h)
                    g.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(color))
                }
            }
        }
    }
}
