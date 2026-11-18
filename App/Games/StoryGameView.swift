import SwiftUI
import BrainCore

struct StoryGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @Environment(AppModel.self) private var model
    @State private var config: StoryConfig
    @State private var rng: SeededRNG
    @State private var phase: Phase = .ready
    @State private var items: [ObjectItem] = []
    @State private var candidates: [ObjectItem] = []
    @State private var storyLines: [String] = []
    @State private var showStory = false
    @State private var usedHint = false
    @State private var studyStart = Date()
    @State private var studyUsed: Double = 0
    @State private var start = Date()
    @State private var cues: [CueQuestion] = []
    @State private var cueIndex = 0
    @State private var cueCorrect = 0
    @State private var number: [Int] = []
    @State private var input: [Int] = []
    @State private var numberChecked = false
    @State private var interference = 0
    @State private var delayedAgeMinutes = 0

    enum Phase { case ready, study, interference, recall, cue, numberInput }

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        _config = State(initialValue: StoryConfig(mode: mode, level: level))
        _rng = State(initialValue: SeededRNG.random())
    }

    var body: some View {
        ZStack {
            switch phase {
            case .ready:
                Color.clear
            case .study:
                if mode == .storyNumber { numberStudy } else { itemStudy }
            case .interference:
                ArithmeticInterlude(level: level, count: 3) { c in
                    interference = c
                    withAnimation { phase = afterInterference }
                }
            case .recall:
                OrderedRecallBoard(expected: items, candidates: candidates,
                                   title: mode == .storyDelayed ? "\(TrainingDetailView.ago(delayedAgeMinutes))的故事，按[顺序]找回来" : "顺着故事，按[顺序]找回来") { picked in
                    finishRecall(picked)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            case .cue:
                cueStage
            case .numberInput:
                numberInputStage
            }
            if phase == .ready {
                ReadyOverlay(subtitle: readyText) { begin() }
            }
        }
    }

    private var readyText: String {
        switch mode {
        case .storyCue: return "把 [\(config.count)] 样东西串成故事，之后问你[前后]是谁"
        case .storyNumber: return "把 [\(config.numberLength)] 位数字换成画面，[编进故事]"
        case .storyDelayed: return "上次编的故事还在吗？[按顺序]找回来"
        default: return "把 [\(config.count)] 样东西编进[一个画面]，越具体越牢"
        }
    }

    private var afterInterference: Phase {
        switch mode {
        case .storyCue: return .cue
        case .storyNumber: return .numberInput
        default: return .recall
        }
    }

    // MARK: 物品学习

    private var itemStudy: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Caption("[\(items.count)] 样东西，编进一个画面", size: 16)
                    Text("画面越具体，记得越牢").font(.song(12)).foregroundColor(Palette.muted)
                }
                Spacer()
                studyTimer
            }
            .padding(.top, 6)
            let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: min(5, max(items.count, 1)))
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    ItemTile(item: item, size: 58, index: i + 1)
                }
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if showStory {
                        ForEach(Array(storyLines.enumerated()), id: \.offset) { i, line in
                            Caption(line, size: 15, weight: .regular, base: Palette.cream)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles").font(.system(size: 24)).foregroundColor(Palette.goldDeep)
                            Caption("自己编一个[荒诞]又具体的故事：颜色、声音、气味、动作", size: 14, weight: .regular, base: Palette.muted)
                            Button("看示范故事（得分 −10%）") {
                                usedHint = true
                                withAnimation { showStory = true }
                            }
                            .buttonStyle(GhostButtonStyle(compact: true))
                        }
                        .padding(.top, 12)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: .infinity)
            .goldCard(padding: 12)
            Button("记好了") { endStudy() }
                .buttonStyle(GoldButtonStyle())
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }

    private var studyTimer: some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
            let remaining = max(0, config.studySeconds - ctx.date.timeIntervalSince(studyStart))
            RingTimer(fraction: remaining / config.studySeconds, label: String(format: "%.0f", remaining.rounded(.up)), size: 62)
                .onChange(of: remaining <= 0) { _, over in
                    if over && phase == .study { endStudy() }
                }
        }
    }

    // MARK: 数字编码学习

    private var numberStudy: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Caption("[\(number.count)] 位数字，变成画面", size: 16)
                    Text("每个数字对应一样东西，再串成故事").font(.song(12)).foregroundColor(Palette.muted)
                }
                Spacer()
                studyTimer
            }
            .padding(.top, 6)
            let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
            LazyVGrid(columns: cols, spacing: 10) {
                ForEach(Array(number.enumerated()), id: \.offset) { i, d in
                    let code = NumberCode.code(d)
                    VStack(spacing: 3) {
                        Text("\(d)").font(.digits(26, .bold)).foregroundColor(Palette.cream)
                        SymbolIcon(name: code.symbol, color: Palette.gold, size: 16)
                        Text(code.name).font(.song(9)).foregroundColor(Palette.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(i / 6 % 2 == 0 ? Palette.card : Palette.cardHi))
                }
            }
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("数字编码表").font(.song(13, .bold)).foregroundColor(Palette.gold)
                    let cols2 = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
                    LazyVGrid(columns: cols2, alignment: .leading, spacing: 8) {
                        ForEach(NumberCode.table, id: \.digit) { c in
                            HStack(spacing: 6) {
                                Text("\(c.digit)").font(.digits(15, .bold)).foregroundColor(Palette.cream).frame(width: 16)
                                SymbolIcon(name: c.symbol, color: Palette.goldDeep, size: 13)
                                Text(c.reason).font(.song(11)).foregroundColor(Palette.muted).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .goldCard(padding: 12)
            Button("记好了") { endStudy() }
                .buttonStyle(GoldButtonStyle())
                .padding(.bottom, 12)
        }
        .padding(.horizontal, 16)
    }

    // MARK: 接龙提问

    private var cueStage: some View {
        VStack(spacing: 18) {
            HStack {
                Text("提问 \(min(cueIndex + 1, cues.count))/\(cues.count)").font(.song(13)).foregroundColor(Palette.muted)
                Spacer()
                Text("答对 \(cueCorrect)").font(.song(13, .bold)).foregroundColor(Palette.gold)
            }
            .padding(.top, 8)
            Spacer(minLength: 0)
            if cueIndex < cues.count {
                let q = cues[cueIndex]
                let name = ItemCatalog.item(q.itemID)?.name ?? ""
                ChoiceQuestion(prompt: q.askNext ? "故事里，[\(name)]后面是什么？" : "故事里，[\(name)]前面是什么？",
                               options: q.options.map { ChoiceQuestion.ChoiceOption(item: ItemCatalog.item($0), text: nil) },
                               answer: q.answer) { ok in
                    if ok { cueCorrect += 1 }
                    if cueIndex + 1 >= cues.count { finishCue() } else { withAnimation { cueIndex += 1 } }
                }
                .id(cueIndex)
                .transition(.opacity)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
    }

    // MARK: 数字输入

    private var numberInputStage: some View {
        VStack(spacing: 16) {
            Caption(numberChecked ? "对照一下哪几位记错了" : "顺着故事，把[数字]写回来", size: 17)
                .padding(.top, 8)
            let cols = Array(repeating: GridItem(.fixed(38), spacing: 5), count: min(8, max(number.count, 1)))
            LazyVGrid(columns: cols, spacing: 8) {
                ForEach(0..<number.count, id: \.self) { i in
                    let v = i < input.count ? input[i] : nil
                    let wrong = numberChecked && v != number[i]
                    VStack(spacing: 2) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(wrong ? Palette.red : (v != nil ? Palette.goldDeep : Palette.lineHi),
                                        style: StrokeStyle(lineWidth: 1, dash: v == nil ? [4, 3] : []))
                            if let v { Text("\(v)").font(.digits(20, .bold)).foregroundColor(wrong ? Palette.red : Palette.cream) }
                        }
                        .frame(width: 38, height: 44)
                        if numberChecked {
                            Text("\(number[i])").font(.digits(11, .bold)).foregroundColor(Palette.gold)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "del", "0", "ok"]
            let kcols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
            LazyVGrid(columns: kcols, spacing: 10) {
                ForEach(keys, id: \.self) { k in
                    Button { press(k) } label: {
                        Group {
                            if k == "del" { Image(systemName: "delete.left").font(.system(size: 20)) }
                            else if k == "ok" { Text("确认").font(.song(18, .bold)) }
                            else { Text(k).font(.digits(24, .semibold)) }
                        }
                        .foregroundColor(k == "ok" ? Palette.ink : Palette.cream)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(k == "ok" ? AnyShapeStyle(Palette.goldGradient) : AnyShapeStyle(Palette.cardHi)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.lineHi, lineWidth: 0.6))
                    }
                    .buttonStyle(PressStyle())
                    .disabled(numberChecked)
                }
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, 16)
    }

    // MARK: 流程

    private func begin() {
        start = Date()
        switch mode {
        case .storyDelayed:
            let pending = model.progress.pendingStory
            items = (pending?.itemIDs ?? []).compactMap { ItemCatalog.item($0) }
            delayedAgeMinutes = Int(Date().timeIntervalSince(pending?.created ?? Date()) / 60)
            if items.count < 3 { items = StoryGenerator.items(config: config, rng: &rng) }
            candidates = (items + ItemCatalog.distractors(for: items, count: config.distractorCount, sameCategory: true, rng: &rng))
                .shuffled(using: &rng)
            withAnimation { phase = .recall }
        case .storyNumber:
            number = StoryGenerator.number(length: config.numberLength, rng: &rng)
            studyStart = Date()
            withAnimation { phase = .study }
        default:
            items = StoryGenerator.items(config: config, rng: &rng)
            storyLines = StoryGenerator.story(for: items, rng: &rng)
            candidates = (items + ItemCatalog.distractors(for: items, count: config.distractorCount,
                                                          sameCategory: level >= 10, rng: &rng)).shuffled(using: &rng)
            if mode == .storyCue { cues = StoryGenerator.cueQuestions(items: items, count: config.cueQuestions, rng: &rng) }
            showStory = config.autoHint && model.settings.showHints
            studyStart = Date()
            withAnimation { phase = .study }
        }
    }

    private func endStudy() {
        guard phase == .study else { return }
        studyUsed = Date().timeIntervalSince(studyStart)
        withAnimation(.easeInOut(duration: 0.3)) {
            phase = config.interference ? .interference : afterInterference
        }
    }

    private func press(_ k: String) {
        guard !numberChecked else { return }
        switch k {
        case "del": if !input.isEmpty { input.removeLast(); Haptic.soft() }
        case "ok":
            guard input.count == number.count else { Haptic.error(); return }
            checkNumber()
        default:
            guard input.count < number.count, let d = Int(k) else { return }
            Haptic.tap()
            input.append(d)
        }
    }

    private func hintFactor() -> Double { usedHint ? 0.9 : 1 }

    private func finishRecall(_ picked: [ObjectItem]) {
        let acc = MemoryGenerator.orderedAccuracy(expected: items, picked: picked)
        if mode != .storyDelayed { model.setPendingStory(items, level: level) }
        let outcome = MemoryGenerator.outcome(accuracy: acc)
        let score = Int((acc * 100 * hintFactor()).rounded())
        let headline: String
        if mode == .storyDelayed {
            headline = acc >= 0.8 ? "隔了这么久，故事[还在]" : "画面再具体一点，才[留得住]"
        } else {
            switch outcome {
            case .excellent: headline = "编成故事的人，记住了[93%]"
            case .pass: headline = "大部分都串上了，画面再[具体]一点"
            case .fail: headline = "给每两样东西之间加一个[动作]"
            }
        }
        var stats = [StatLine(label: "顺序全对", value: "\(Int((acc * Double(items.count)).rounded())) / \(items.count)")]
        if mode == .storyDelayed {
            stats.append(StatLine(label: "间隔", value: TrainingDetailView.ago(delayedAgeMinutes)))
        } else {
            stats.append(StatLine(label: "记忆用时", value: Fmt.seconds(studyUsed)))
            stats.append(StatLine(label: "示范故事", value: usedHint ? "看了（−10%）" : (showStory ? "自动给出" : "没看")))
            if config.interference { stats.append(StatLine(label: "干扰算术", value: "\(interference) / 3")) }
            stats.append(StatLine(label: "稍后", value: "20 分钟后可以做「延迟回忆」"))
        }
        onFinish(GameResult(score: score, outcome: outcome, accuracy: acc, meanRT: nil,
                            duration: Date().timeIntervalSince(start), headline: headline, stats: stats))
    }

    private func finishCue() {
        model.setPendingStory(items, level: level)
        let acc = Double(cueCorrect) / Double(max(cues.count, 1))
        let outcome: Outcome = acc >= 0.999 ? .excellent : (acc >= 0.66 ? .pass : .fail)
        onFinish(GameResult(score: Int((acc * 100 * hintFactor()).rounded()), outcome: outcome, accuracy: acc, meanRT: nil,
                            duration: Date().timeIntervalSince(start),
                            headline: outcome == .fail ? "故事要[一环扣一环]，前后才问得出来" : "故事一环扣一环，[前后]都清楚",
                            stats: [StatLine(label: "答对", value: "\(cueCorrect) / \(cues.count)"),
                                    StatLine(label: "清单", value: "\(items.count) 样"),
                                    StatLine(label: "记忆用时", value: Fmt.seconds(studyUsed))]))
    }

    private func checkNumber() {
        numberChecked = true
        let acc = DigitGenerator.positionAccuracy(expected: number, answer: input)
        if acc >= 0.999 { Haptic.success(); SFX.correct() } else { Haptic.error() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            let outcome: Outcome = acc >= 0.999 ? .excellent : (acc >= 0.85 ? .pass : .fail)
            onFinish(GameResult(score: Int((acc * 100).rounded()), outcome: outcome, accuracy: acc, meanRT: nil,
                                duration: Date().timeIntervalSince(start),
                                headline: outcome == .fail ? "先把编码表[背熟]，故事才编得快" : "数字也能[编进故事]",
                                stats: [StatLine(label: "位置正确", value: Fmt.percent(acc)),
                                        StatLine(label: "位数", value: "\(number.count) 位"),
                                        StatLine(label: "记忆用时", value: Fmt.seconds(studyUsed))]))
        }
    }
}
