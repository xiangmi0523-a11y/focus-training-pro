import Foundation

public enum InkColor: Int, CaseIterable, Codable, Sendable, Hashable {
    case red, green, yellow, blue, purple, orange

    public var name: String {
        switch self {
        case .red: return "红"
        case .green: return "绿"
        case .yellow: return "黄"
        case .blue: return "蓝"
        case .purple: return "紫"
        case .orange: return "橙"
        }
    }

    /// 语音识别时可能听成的同音字
    public var soundAlikes: [Character] {
        switch self {
        case .red: return ["红", "洪", "宏", "鸿", "虹", "弘"]
        case .green: return ["绿", "律", "虑", "率", "滤", "旅", "吕", "铝"]
        case .yellow: return ["黄", "皇", "煌", "慌", "晃", "凰", "惶"]
        case .blue: return ["蓝", "兰", "拦", "栏", "篮", "澜", "岚", "南"]
        case .purple: return ["紫", "子", "字", "自", "姊", "梓", "籽"]
        case .orange: return ["橙", "成", "城", "程", "承", "诚", "乘", "呈"]
        }
    }

    public static func match(_ ch: Character, among colors: [InkColor]) -> InkColor? {
        colors.first { $0.soundAlikes.contains(ch) }
    }
}

public enum Direction4: Int, CaseIterable, Codable, Sendable, Hashable {
    case up, down, left, right

    public var name: String {
        switch self {
        case .up: return "上"
        case .down: return "下"
        case .left: return "左"
        case .right: return "右"
        }
    }

    public var symbol: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        }
    }
}

public enum StroopCue: Sendable, Hashable { case color, word }

public struct StroopTrial: Sendable, Hashable {
    public enum Stimulus: Sendable, Hashable {
        case colorWord(word: InkColor, ink: InkColor, cue: StroopCue)
        case count(digit: Int, count: Int)
        case direction(word: Direction4, position: Direction4)
    }

    public let stimulus: Stimulus
    /// 正确按钮的序号
    public let answer: Int
    public let congruent: Bool
    /// 切换模式下，与上一题规则不同
    public let isSwitch: Bool
}

public struct StroopConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let colors: [InkColor]
    public let itemTime: Double
    public let congruentRatio: Double
    public let switchRate: Double
    public let total: Int
    /// 高等级时每页打乱按钮位置，防止形成肌肉记忆
    public let shuffleButtons: Bool

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        let colorCount = lv < 6 ? 4 : (lv < 14 ? 5 : 6)
        self.colors = Array(InkColor.allCases.prefix(colorCount))
        var t = max(0.75, 2.6 - 0.065 * Double(lv))
        if mode == .stroopSwitch { t += 0.35 }
        self.itemTime = (t * 100).rounded() / 100
        self.congruentRatio = max(0.1, 0.4 - 0.015 * Double(lv))
        self.switchRate = min(0.55, 0.25 + 0.012 * Double(lv))
        switch mode {
        case .stroopColor, .stroopSwitch: self.total = 24
        default: self.total = 24 + min(12, lv / 2)
        }
        self.shuffleButtons = lv >= 10
    }

    /// 按钮数量
    public var buttonCount: Int {
        switch mode {
        case .stroopCount: return level < 10 ? 4 : 5
        case .stroopDirection: return 4
        default: return colors.count
        }
    }
}

public enum StroopGenerator {
    public static func trials(config: StroopConfig, rng: inout SeededRNG) -> [StroopTrial] {
        var out: [StroopTrial] = []
        var lastCue: StroopCue = .color
        var lastAnswer = -1
        for i in 0..<config.total {
            let congruent = rng.chance(config.congruentRatio)
            var trial: StroopTrial
            var attempts = 0
            repeat {
                attempts += 1
                switch config.mode {
                case .stroopCount:
                    let maxCount = config.buttonCount
                    let count = rng.int(in: 1...maxCount)
                    var digit = count
                    if !congruent {
                        repeat { digit = rng.int(in: 1...9) } while digit == count
                    }
                    trial = StroopTrial(stimulus: .count(digit: digit, count: count), answer: count - 1,
                                        congruent: congruent, isSwitch: false)
                case .stroopDirection:
                    let pos = Direction4.allCases.randomElement(using: &rng)!
                    var word = pos
                    if !congruent {
                        repeat { word = Direction4.allCases.randomElement(using: &rng)! } while word == pos
                    }
                    trial = StroopTrial(stimulus: .direction(word: word, position: pos), answer: pos.rawValue,
                                        congruent: congruent, isSwitch: false)
                default:
                    let ink = config.colors.randomElement(using: &rng)!
                    var word = ink
                    if !congruent {
                        repeat { word = config.colors.randomElement(using: &rng)! } while word == ink
                    }
                    var cue: StroopCue = .color
                    if config.mode == .stroopSwitch && i > 0 {
                        cue = rng.chance(config.switchRate) ? (lastCue == .color ? .word : .color) : lastCue
                    }
                    let answerColor = cue == .color ? ink : word
                    let answer = config.colors.firstIndex(of: answerColor) ?? 0
                    trial = StroopTrial(stimulus: .colorWord(word: word, ink: ink, cue: cue), answer: answer,
                                        congruent: congruent, isSwitch: config.mode == .stroopSwitch && cue != lastCue)
                }
            } while trial.answer == lastAnswer && attempts < 4 && rng.chance(0.7)
            if case let .colorWord(_, _, cue) = trial.stimulus { lastCue = cue }
            lastAnswer = trial.answer
            out.append(trial)
        }
        return out
    }
}

public struct StroopResponse: Sendable, Hashable {
    public let trial: StroopTrial
    public let correct: Bool
    /// nil 表示超时
    public let rt: Double?

    public init(trial: StroopTrial, correct: Bool, rt: Double?) {
        self.trial = trial
        self.correct = correct
        self.rt = rt
    }
}

public struct StroopSummary: Sendable {
    public let score: Int
    public let outcome: Outcome
    public let accuracy: Double
    public let meanRT: Double?
    /// 不一致题比一致题慢多少毫秒
    public let interferenceMs: Int?
    public let switchCostMs: Int?
    public let timeouts: Int
}

public enum StroopScorer {
    public static func evaluate(_ responses: [StroopResponse], config: StroopConfig) -> StroopSummary {
        let total = max(responses.count, 1)
        let correct = responses.filter(\.correct)
        let accuracy = Double(correct.count) / Double(total)
        let rts = correct.compactMap(\.rt)
        let mean = rts.isEmpty ? nil : rts.reduce(0, +) / Double(rts.count)
        func avg(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }
        let inc = avg(correct.filter { !$0.trial.congruent }.compactMap(\.rt))
        let con = avg(correct.filter { $0.trial.congruent }.compactMap(\.rt))
        var interference: Int?
        if let i = inc, let c = con { interference = Int(((i - c) * 1000).rounded()) }
        var switchCost: Int?
        if config.mode == .stroopSwitch {
            let sw = avg(correct.filter { $0.trial.isSwitch }.compactMap(\.rt))
            let st = avg(correct.filter { !$0.trial.isSwitch }.compactMap(\.rt))
            if let a = sw, let b = st { switchCost = Int(((a - b) * 1000).rounded()) }
        }
        let speed = mean.map { clamp(1 - $0 / config.itemTime, 0, 1) } ?? 0
        let score = Int((accuracy * 72 + speed * 28 * accuracy).rounded())
        let outcome: Outcome
        if accuracy >= 0.96, let m = mean, m <= config.itemTime * 0.55 {
            outcome = .excellent
        } else if accuracy >= 0.85 {
            outcome = .pass
        } else {
            outcome = .fail
        }
        return StroopSummary(score: clamp(score, 0, 100), outcome: outcome, accuracy: accuracy, meanRT: mean,
                             interferenceMs: interference, switchCostMs: switchCost,
                             timeouts: responses.filter { $0.rt == nil }.count)
    }
}
