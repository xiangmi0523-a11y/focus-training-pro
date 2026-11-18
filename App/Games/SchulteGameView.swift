import SwiftUI
import BrainCore

struct SchulteGameView: View {
    let mode: ModeID
    let level: Int
    let onFinish: (GameResult) -> Void

    @State private var config: SchulteConfig
    @State private var board: SchulteBoard
    @State private var rng: SeededRNG
    @State private var ready = false
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var wrongFlash: Int?
    @State private var rightFlash: Int?
    @State private var done = false

    init(mode: ModeID, level: Int, onFinish: @escaping (GameResult) -> Void) {
        self.mode = mode
        self.level = level
        self.onFinish = onFinish
        var r = SeededRNG.random()
        let c = SchulteConfig(mode: mode, level: level)
        _config = State(initialValue: c)
        _board = State(initialValue: SchulteBoard(config: c, rng: &r))
        _rng = State(initialValue: r)
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                header
                Spacer(minLength: 0)
                grid
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            if done {
                GoldCheck(size: 120).transition(.scale.combined(with: .opacity))
            }
            if !ready {
                ReadyOverlay(subtitle: instruction) {
                    withAnimation { ready = true }
                    startDate = Date()
                    SFX.start()
                }
            }
        }
    }

    private var instruction: String {
        switch mode {
        case .schulteReverse: return "从[\(config.size * config.size)]倒着找回[1]"
        case .schulteLetters: return "按字母顺序 [A → \(board.sequence.last?.label ?? "Z")]"
        case .schultePoem: return "按《\(board.poem?.title ?? "")》的字序找，[干扰字]别点"
        case .schulteDynamic: return "每点对一个，整盘就[重新打乱]"
        case .schulteGorbov: return "[金色]从1往上数，[红色]从大往下数，交替进行"
        default: return "眼睛盯住中间，用[余光]去找"
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Caption(instruction, size: 14, weight: .regular, base: Palette.muted, alignment: .leading)
                HStack(spacing: 8) {
                    Text("目标").font(.song(12)).foregroundColor(Palette.muted)
                    Text(String(format: "%.1f 秒", config.targetTime)).font(.song(14, .bold)).foregroundColor(Palette.gold)
                    if board.errors > 0 {
                        Text("罚时 +\(board.errors)s").font(.song(12, .bold)).foregroundColor(Palette.red)
                    }
                }
                if let poem = board.poem {
                    Text("《\(poem.title)》\(poem.author)").font(.song(12)).foregroundColor(Palette.goldDeep)
                }
                HStack(spacing: 6) {
                    Text("进度").font(.song(12)).foregroundColor(Palette.muted)
                    Text("\(board.progress)/\(board.sequence.count)").font(.digits(14, .bold)).foregroundColor(Palette.cream)
                }
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                let elapsed = elapsedTime(at: ctx.date)
                let remaining = config.targetTime - elapsed
                RingTimer(fraction: remaining / config.targetTime,
                          label: remaining >= 0 ? String(format: "%.0f", remaining.rounded(.up)) : String(format: "+%.0f", -remaining),
                          size: 84, warning: remaining < 0)
                    .onChange(of: remaining < -config.targetTime) { _, over in
                        if over && !done { timeout() }
                    }
            }
        }
    }

    private func elapsedTime(at date: Date) -> Double {
        guard let s = startDate else { return 0 }
        return (endDate ?? date).timeIntervalSince(s) + Double(board.errors)
    }

    private var grid: some View {
        GeometryReader { geo in
            let n = config.size
            let spacing: CGFloat = n >= 7 ? 4 : 6
            let side = min(geo.size.width, geo.size.height)
            let cell = (side - spacing * CGFloat(n - 1)) / CGFloat(n)
            let cols = Array(repeating: GridItem(.fixed(cell), spacing: spacing), count: n)
            ZStack {
                LazyVGrid(columns: cols, spacing: spacing) {
                    ForEach(Array(board.cells.enumerated()), id: \.element.id) { index, c in
                        cellView(c, index: index, size: cell)
                    }
                }
                .frame(width: side, height: side)
                // 中心注视点
                Circle()
                    .fill(Palette.gold.opacity(0.85))
                    .frame(width: 6, height: 6)
                    .shadow(color: Palette.gold, radius: 6)
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .opacity(ready ? 1 : 0.25)
        .blur(radius: ready ? 0 : 6)
    }

    private func cellView(_ c: SchulteCell, index: Int, size: CGFloat) -> some View {
        let found = c.found && config.markFound
        let textColor: Color = {
            switch c.tint {
            case .gold: return Palette.gold
            case .red: return Palette.red
            case .plain: return Palette.cream
            }
        }()
        let isWrong = wrongFlash == c.id
        let isRight = rightFlash == c.id
        return Button {
            tap(index)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.14)
                    .fill(found ? Palette.gold.opacity(0.18) : (isRight ? Palette.gold.opacity(0.3) : Palette.card))
                RoundedRectangle(cornerRadius: size * 0.14)
                    .stroke(isWrong ? Palette.red : (isRight ? Palette.gold : Palette.line), lineWidth: isWrong || isRight ? 1.6 : 0.8)
                Text(c.label)
                    .font(mode == .schultePoem || mode == .schulteLetters ? .song(size * 0.44, .bold) : .digits(size * 0.4, .semibold))
                    .foregroundColor(found ? textColor.opacity(0.45) : textColor)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
        .disabled(!ready || done)
    }

    private var footer: some View {
        HStack {
            if config.size >= 6 && !config.markFound {
                Text("高等级不标记已找到的格子").font(.song(11)).foregroundColor(Palette.faint)
            }
            Spacer()
            if mode == .schulteGorbov, let next = board.nextTarget {
                HStack(spacing: 4) {
                    Text("下一个颜色").font(.song(11)).foregroundColor(Palette.muted)
                    Circle().fill(next.tint == .red ? Palette.red : Palette.gold).frame(width: 9, height: 9)
                }
            }
        }
        .frame(height: 18)
    }

    private func tap(_ index: Int) {
        guard ready, !done, index < board.cells.count else { return }
        let id = board.cells[index].id
        if board.tap(index) {
            Haptic.tap()
            SFX.tick()
            rightFlash = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { if rightFlash == id { rightFlash = nil } }
            if config.shuffleOnTap && !board.isComplete {
                withAnimation(.easeInOut(duration: 0.32)) { board.reshuffle(rng: &rng) }
            }
            if board.isComplete { complete() }
        } else {
            Haptic.error()
            wrongFlash = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { if wrongFlash == id { wrongFlash = nil } }
        }
    }

    private func complete() {
        endDate = Date()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { done = true }
        Haptic.success()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { report(completed: true) }
    }

    private func timeout() {
        endDate = Date()
        done = true
        report(completed: false)
    }

    private func report(completed: Bool) {
        let raw = (endDate ?? Date()).timeIntervalSince(startDate ?? Date())
        let eval = SchulteBoard.evaluate(elapsed: raw, errors: board.errors, completed: completed, config: config)
        let headline: String
        switch eval.outcome {
        case .excellent: headline = "比目标快了 [\(String(format: "%.1f", config.targetTime - eval.effective)) 秒]，余光越来越宽"
        case .pass: headline = "目标时间内找完，就算[过关]"
        case .fail: headline = completed ? "刚开始慢很正常，[多练几次]就快了" : "时间用完了，下次眼睛[盯住中间]试试"
        }
        let perCell = raw / Double(max(board.progress, 1))
        onFinish(GameResult(
            score: eval.score, outcome: eval.outcome,
            accuracy: Double(board.progress) / Double(max(board.progress + board.errors, 1)),
            meanRT: perCell, duration: raw, headline: headline,
            stats: [
                StatLine(label: "用时", value: Fmt.seconds(raw)),
                StatLine(label: "错误 / 罚时", value: "\(board.errors) 次 / +\(board.errors) 秒"),
                StatLine(label: "目标", value: Fmt.seconds(config.targetTime)),
                StatLine(label: "平均每格", value: Fmt.ms(perCell)),
                StatLine(label: "方格", value: "\(config.size) × \(config.size)")
            ]))
    }
}
