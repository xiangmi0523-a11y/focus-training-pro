import Foundation

public struct MemoryConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let count: Int
    public let showTime: Double
    public let distractorCount: Int
    public let sameCategoryDistractors: Bool
    /// 记完后插一段算术干扰
    public let interference: Bool
    public let probeQuestions: Int
    public let changeRounds: Int

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        switch mode {
        case .memoryChange:
            count = min(10, 4 + lv / 4)
        case .memoryProbe:
            count = min(12, 6 + lv / 4)
        default:
            count = min(13, 5 + lv / 3)
        }
        showTime = max(0.8, 2.2 - 0.05 * Double(lv))
        distractorCount = min(11, 3 + lv / 3)
        sameCategoryDistractors = lv >= 10
        interference = lv >= 8 && (mode == .memoryOrdered || mode == .memoryReverse)
        probeQuestions = 6
        changeRounds = 5
    }

    /// 找变化模式：整排展示的时间
    public var changeStudyTime: Double { max(2.0, Double(count) * max(0.5, 1.1 - 0.025 * Double(level))) }
}

public struct MemoryProbe: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        /// 第 position 个（从 0 起）是什么？
        case whatAt(position: Int)
        /// 某物品排第几？
        case whereIs(itemID: String)
    }

    public let kind: Kind
    /// whatAt：选项是物品 id；whereIs：选项是位置序号字符串
    public let options: [String]
    public let answer: Int
}

public struct ChangeRound: Sendable, Hashable {
    public let before: [ObjectItem]
    public let after: [ObjectItem]
    /// 发生变化的位置
    public let changed: Set<Int>
    public let isSwap: Bool
}

public struct ArithmeticTask: Sendable, Hashable {
    public let text: String
    public let options: [Int]
    public let answer: Int

    public static func make(rng: inout SeededRNG, level: Int) -> ArithmeticTask {
        let hard = level >= 15
        let a = rng.int(in: hard ? 23...97 : 12...59)
        let b = rng.int(in: hard ? 6...38 : 3...19)
        let plus = rng.chance(0.5)
        let result = plus ? a + b : a - b
        var options: Set<Int> = [result]
        while options.count < 3 {
            let delta = rng.int(in: 1...9) * (rng.chance(0.5) ? 1 : -1)
            options.insert(result + (rng.chance(0.4) ? delta * 10 : delta))
        }
        let list = Array(options).shuffled(using: &rng)
        return ArithmeticTask(text: "\(a) \(plus ? "+" : "−") \(b)", options: list, answer: list.firstIndex(of: result) ?? 0)
    }
}

public enum MemoryGenerator {
    public static func study(config: MemoryConfig, rng: inout SeededRNG) -> [ObjectItem] {
        ItemCatalog.pick(config.count, rng: &rng)
    }

    public static func candidates(study: [ObjectItem], config: MemoryConfig, rng: inout SeededRNG) -> [ObjectItem] {
        let extra = ItemCatalog.distractors(for: study, count: config.distractorCount,
                                            sameCategory: config.sameCategoryDistractors, rng: &rng)
        return (study + extra).shuffled(using: &rng)
    }

    public static func probes(study: [ObjectItem], count: Int, rng: inout SeededRNG) -> [MemoryProbe] {
        var out: [MemoryProbe] = []
        var positions = Array(0..<study.count).shuffled(using: &rng)
        for i in 0..<count {
            if positions.isEmpty { positions = Array(0..<study.count).shuffled(using: &rng) }
            let pos = positions.removeFirst()
            if i % 2 == 0 {
                // 第几个是什么：选项来自清单里的其他物品（更难）
                var opts = [study[pos].id]
                let others = study.indices.filter { $0 != pos }.shuffled(using: &rng)
                for o in others.prefix(3) { opts.append(study[o].id) }
                opts.shuffle(using: &rng)
                out.append(MemoryProbe(kind: .whatAt(position: pos), options: opts, answer: opts.firstIndex(of: study[pos].id) ?? 0))
            } else {
                // 排第几：选项为邻近位置
                var set: Set<Int> = [pos]
                var spread = 1
                while set.count < min(4, study.count) {
                    for d in [spread, -spread] where set.count < min(4, study.count) {
                        let p = pos + d
                        if p >= 0 && p < study.count { set.insert(p) }
                    }
                    spread += 1
                }
                let opts = set.sorted().map { "\($0 + 1)" }
                out.append(MemoryProbe(kind: .whereIs(itemID: study[pos].id), options: opts,
                                       answer: opts.firstIndex(of: "\(pos + 1)") ?? 0))
            }
        }
        return out
    }

    public static func changeRound(config: MemoryConfig, rng: inout SeededRNG) -> ChangeRound {
        let before = ItemCatalog.pick(config.count, rng: &rng)
        var after = before
        let swap = rng.chance(0.5)
        var changed: Set<Int> = []
        if swap {
            let i = rng.int(before.count)
            var j = rng.int(before.count)
            while j == i { j = rng.int(before.count) }
            after.swapAt(i, j)
            changed = [i, j]
        } else {
            let i = rng.int(before.count)
            let replacement = ItemCatalog.distractors(for: before, count: 1, sameCategory: config.level >= 12, rng: &rng)
            if let r = replacement.first {
                after[i] = r
                changed = [i]
            }
        }
        return ChangeRound(before: before, after: after, changed: changed, isSwap: swap)
    }

    /// 顺序回忆评分：位置完全正确的比例
    public static func orderedAccuracy(expected: [ObjectItem], picked: [ObjectItem]) -> Double {
        guard !expected.isEmpty else { return 0 }
        var hit = 0
        for (i, e) in expected.enumerated() where i < picked.count && picked[i].id == e.id { hit += 1 }
        return Double(hit) / Double(expected.count)
    }

    public static func outcome(accuracy: Double) -> Outcome {
        if accuracy >= 0.999 { return .excellent }
        if accuracy >= 0.8 { return .pass }
        return .fail
    }
}
