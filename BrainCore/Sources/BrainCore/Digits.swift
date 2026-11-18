import Foundation

public struct DigitConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let length: Int
    public let trials: Int
    /// 两个数字之间的间隔（秒，起点到起点）
    public let interval: Double
    /// 背景人声噪音 0...1
    public let noise: Double
    /// 干扰声音音量 0...1（鸡尾酒会模式）
    public let distractorVolume: Double
    public let speechRate: Float

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        var len = min(13, 4 + (lv + 1) / 2)
        switch mode {
        case .digitsBackward, .digitsSorted: len = min(11, len - 1)
        case .digitsCocktail: len = min(10, 3 + (lv + 1) / 2)
        default: break
        }
        self.length = max(3, len)
        self.trials = 3
        self.interval = max(0.55, 1.0 - 0.015 * Double(lv))
        self.noise = mode == .digitsCocktail ? min(0.35, 0.02 * Double(lv)) : min(0.85, 0.035 * Double(lv))
        self.distractorVolume = min(1.0, 0.35 + 0.03 * Double(lv))
        self.speechRate = Float(min(0.62, 0.5 + 0.004 * Double(lv)))
    }
}

public enum DigitGenerator {
    /// 不出现连续重复和 3 个以上的连续递增/递减
    public static func sequence(length: Int, rng: inout SeededRNG) -> [Int] {
        var out: [Int] = []
        while out.count < length {
            let d = rng.int(10)
            if let last = out.last, last == d { continue }
            if out.count >= 2 {
                let a = out[out.count - 2], b = out[out.count - 1]
                if (b - a == 1 && d - b == 1) || (b - a == -1 && d - b == -1) { continue }
            }
            out.append(d)
        }
        return out
    }

    /// 干扰声音读的数字：与目标同位不同
    public static func distractor(for target: [Int], rng: inout SeededRNG) -> [Int] {
        target.map { t in
            var d = rng.int(10)
            while d == t { d = rng.int(10) }
            return d
        }
    }

    public static func expected(_ seq: [Int], mode: ModeID) -> [Int] {
        switch mode {
        case .digitsBackward: return seq.reversed()
        case .digitsSorted: return seq.sorted()
        default: return seq
        }
    }

    public static func positionAccuracy(expected: [Int], answer: [Int]) -> Double {
        guard !expected.isEmpty else { return 0 }
        var hit = 0
        for (i, e) in expected.enumerated() where i < answer.count && answer[i] == e { hit += 1 }
        return Double(hit) / Double(expected.count)
    }

    public static func evaluate(exact: Int, trials: Int, meanPositionAccuracy: Double) -> (score: Int, outcome: Outcome) {
        let score = Int((meanPositionAccuracy * 70 + Double(exact) / Double(max(trials, 1)) * 30).rounded())
        let outcome: Outcome
        if exact == trials { outcome = .excellent } else if exact * 3 >= trials * 2 { outcome = .pass } else { outcome = .fail }
        return (clamp(score, 0, 100), outcome)
    }
}

/// 数字编码（串成故事 · 数字编码模式）
public struct NumberCode: Sendable, Hashable {
    public let digit: Int
    public let name: String
    public let symbol: String
    public let reason: String

    public static let table: [NumberCode] = [
        NumberCode(digit: 0, name: "鸡蛋", symbol: "oval.portrait.fill", reason: "0 圆圆的像鸡蛋"),
        NumberCode(digit: 1, name: "铅笔", symbol: "pencil", reason: "1 细细长长像铅笔"),
        NumberCode(digit: 2, name: "鸭子", symbol: "bird.fill", reason: "2 像浮在水上的鸭子"),
        NumberCode(digit: 3, name: "耳朵", symbol: "ear.fill", reason: "3 像一只耳朵"),
        NumberCode(digit: 4, name: "小旗", symbol: "flag.fill", reason: "4 像一面小旗"),
        NumberCode(digit: 5, name: "手掌", symbol: "hand.raised.fill", reason: "5 根手指一只手"),
        NumberCode(digit: 6, name: "骰子", symbol: "die.face.6.fill", reason: "骰子最大是 6"),
        NumberCode(digit: 7, name: "瓢虫", symbol: "ladybug.fill", reason: "七星瓢虫"),
        NumberCode(digit: 8, name: "眼镜", symbol: "eyeglasses", reason: "8 横过来像眼镜"),
        NumberCode(digit: 9, name: "气球", symbol: "balloon.fill", reason: "9 像牵着线的气球")
    ]

    public static func code(_ d: Int) -> NumberCode { table[clamp(d, 0, 9)] }
}
