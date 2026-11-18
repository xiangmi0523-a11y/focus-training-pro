import Foundation

public struct StoryConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let count: Int
    public let studySeconds: Double
    /// 低等级自动给示范故事
    public let autoHint: Bool
    public let distractorCount: Int
    public let interference: Bool
    public let cueQuestions: Int
    public let numberLength: Int

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        count = min(15, 5 + (lv + 1) / 3)
        let per = max(2.5, 7.5 - 0.17 * Double(lv))
        if mode == .storyNumber {
            numberLength = min(24, 8 + lv / 2 * 1 + lv / 6)
            studySeconds = (Double(numberLength) * max(1.6, 4.0 - 0.08 * Double(lv))).rounded()
        } else {
            numberLength = 0
            studySeconds = (Double(count) * per).rounded()
        }
        autoHint = lv < 6
        distractorCount = min(12, 4 + lv / 3)
        interference = lv >= 4
        cueQuestions = 6
    }
}

public struct CueQuestion: Sendable, Hashable {
    public let itemID: String
    /// true: 问后一个；false: 问前一个
    public let askNext: Bool
    public let options: [String]
    public let answer: Int
}

public enum StoryGenerator {
    private static let connectors: [String] = [
        "{a}里，突然钻出{b}",
        "{a}上面，稳稳站着{b}",
        "{b}一头撞翻了{a}",
        "{a}慢慢变成了{b}",
        "{b}骑着{a}飞上了天",
        "{a}被{b}一口吞了下去",
        "{a}旁边，堆满了{b}",
        "{b}从{a}的窗口飘出来",
        "{a}轻轻一碰，就弹出{b}",
        "{b}挂在{a}的尖上，晃来晃去",
        "{a}打了个喷嚏，喷出{b}",
        "{b}把{a}当成了帽子戴上"
    ]

    /// 示范故事：一行一个画面
    public static func story(for items: [ObjectItem], rng: inout SeededRNG) -> [String] {
        guard let first = items.first else { return [] }
        var lines = ["开头是\(first.image)"]
        var pool = connectors.shuffled(using: &rng)
        for i in 1..<max(items.count, 1) where i < items.count {
            if pool.isEmpty { pool = connectors.shuffled(using: &rng) }
            let template = pool.removeFirst()
            let a = items[i - 1].name
            let b = items[i].image
            lines.append(template.replacingOccurrences(of: "{a}", with: a).replacingOccurrences(of: "{b}", with: b))
        }
        return lines
    }

    public static func items(config: StoryConfig, rng: inout SeededRNG) -> [ObjectItem] {
        ItemCatalog.pick(config.count, rng: &rng)
    }

    public static func cueQuestions(items: [ObjectItem], count: Int, rng: inout SeededRNG) -> [CueQuestion] {
        guard items.count >= 3 else { return [] }
        var out: [CueQuestion] = []
        var used: Set<Int> = []
        let possible = 2 * (items.count - 1)
        while out.count < count && used.count < possible {
            let askNext = rng.chance(0.6)
            let idx = askNext ? rng.int(items.count - 1) : 1 + rng.int(items.count - 1)
            let key = idx * 2 + (askNext ? 1 : 0)
            if used.contains(key) { continue }
            used.insert(key)
            let answerIdx = askNext ? idx + 1 : idx - 1
            var opts = [items[answerIdx].id]
            // 干扰选项：清单里相邻的其他物品，最具迷惑性
            let near = items.indices.filter { $0 != answerIdx && $0 != idx }
                .sorted { abs($0 - answerIdx) < abs($1 - answerIdx) }
            for n in near.prefix(3) { opts.append(items[n].id) }
            opts.shuffle(using: &rng)
            out.append(CueQuestion(itemID: items[idx].id, askNext: askNext, options: opts,
                                   answer: opts.firstIndex(of: items[answerIdx].id) ?? 0))
        }
        return out
    }

    public static func number(length: Int, rng: inout SeededRNG) -> [Int] {
        (0..<length).map { _ in rng.int(10) }
    }
}
