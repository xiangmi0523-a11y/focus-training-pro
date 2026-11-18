import Foundation

public enum SortRule: Int, CaseIterable, Codable, Sendable, Hashable {
    case category, price, color

    public var title: String {
        switch self {
        case .category: return "类别"
        case .price: return "价格"
        case .color: return "颜色"
        }
    }

    public var buckets: [String] {
        switch self {
        case .category: return SortCategory.allCases.map(\.name)
        case .price: return PriceTier.allCases.map(\.name)
        case .color: return TintChoice.allCases.map(\.name)
        }
    }
}

public enum SortCategory: Int, CaseIterable, Codable, Sendable, Hashable {
    case food, stationery, daily

    public var name: String {
        switch self {
        case .food: return "食品"
        case .stationery: return "文具"
        case .daily: return "日用品"
        }
    }
}

public enum PriceTier: Int, CaseIterable, Codable, Sendable, Hashable {
    case low, mid, high

    public var name: String {
        switch self {
        case .low: return "低价"
        case .mid: return "中价"
        case .high: return "高价"
        }
    }

    public var range: ClosedRange<Int> {
        switch self {
        case .low: return 1...14
        case .mid: return 15...59
        case .high: return 60...399
        }
    }

    public static func tier(for price: Int) -> PriceTier {
        if price < 15 { return .low }
        if price < 60 { return .mid }
        return .high
    }
}

public enum TintChoice: Int, CaseIterable, Codable, Sendable, Hashable {
    case red, blue, green

    public var name: String {
        switch self {
        case .red: return "红色"
        case .blue: return "蓝色"
        case .green: return "绿色"
        }
    }
}

public struct SortItem: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String
    public let category: SortCategory

    public init(_ id: String, _ name: String, _ symbol: String, _ category: SortCategory) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.category = category
    }
}

public enum SortCatalog {
    public static let all: [SortItem] = [
        SortItem("cake", "蛋糕", "birthday.cake.fill", .food),
        SortItem("carrot", "胡萝卜", "carrot.fill", .food),
        SortItem("coffee", "咖啡", "cup.and.saucer.fill", .food),
        SortItem("tea", "热茶", "mug.fill", .food),
        SortItem("set", "汉堡套餐", "takeoutbag.and.cup.and.straw.fill", .food),
        SortItem("wine", "红酒", "wineglass.fill", .food),
        SortItem("popcorn", "爆米花", "popcorn.fill", .food),
        SortItem("fish", "鲜鱼", "fish.fill", .food),
        SortItem("leaf", "茶叶", "leaf.fill", .food),
        SortItem("pencil", "铅笔", "pencil", .stationery),
        SortItem("ruler", "尺子", "ruler.fill", .stationery),
        SortItem("clip", "回形针", "paperclip", .stationery),
        SortItem("scissors", "剪刀", "scissors", .stationery),
        SortItem("notebook", "笔记本", "book.closed.fill", .stationery),
        SortItem("brush", "毛笔", "paintbrush.fill", .stationery),
        SortItem("pin", "图钉", "pin.fill", .stationery),
        SortItem("folder", "文件夹", "folder.fill", .stationery),
        SortItem("highlighter", "荧光笔", "highlighter", .stationery),
        SortItem("umbrella", "雨伞", "umbrella.fill", .daily),
        SortItem("bulb", "灯泡", "lightbulb.fill", .daily),
        SortItem("lamp", "台灯", "lamp.desk.fill", .daily),
        SortItem("key", "钥匙", "key.fill", .daily),
        SortItem("torch", "手电筒", "flashlight.on.fill", .daily),
        SortItem("shirt", "T恤", "tshirt.fill", .daily),
        SortItem("bag", "购物袋", "bag.fill", .daily),
        SortItem("pan", "平底锅", "frying.pan.fill", .daily),
        SortItem("bin", "垃圾桶", "trash.fill", .daily),
        SortItem("alarm", "闹钟", "alarm.fill", .daily)
    ]
}

public struct SortTrial: Sendable, Hashable {
    public let item: SortItem
    public let price: Int
    public let tint: TintChoice
    /// 本题规则（隐藏规则模式由引擎决定，这里不用）
    public let rule: SortRule
    public let ruleChanged: Bool

    public var tier: PriceTier { PriceTier.tier(for: price) }

    public func answer(for rule: SortRule) -> Int {
        switch rule {
        case .category: return item.category.rawValue
        case .price: return tier.rawValue
        case .color: return tint.rawValue
        }
    }
}

public struct SortConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let itemTime: Double
    public let trials: Int
    public let rules: [SortRule]
    /// 固定每几题切换；nil 表示随机切换
    public let switchEvery: Int?
    public let randomSwitchProb: Double
    /// 隐藏规则：连对几次后偷偷换规则
    public let hiddenRun: Int

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        var t = max(0.9, 3.0 - 0.07 * Double(lv))
        if mode == .sortHidden { t = max(1.6, 4.0 - 0.07 * Double(lv)) }
        self.itemTime = (t * 100).rounded() / 100
        switch mode {
        case .sortSingle:
            trials = min(36, 20 + lv / 2)
            rules = [.category]
            switchEvery = nil
        case .sortSwitch:
            trials = min(40, 24 + lv / 2)
            rules = lv >= 8 ? [.category, .price, .color] : [.category, .price]
            switchEvery = lv < 6 ? 6 : (lv < 12 ? 4 : nil)
        default:
            trials = min(48, 36 + lv / 2)
            rules = [.category, .price, .color]
            switchEvery = nil
        }
        randomSwitchProb = min(0.45, 0.25 + 0.01 * Double(lv))
        hiddenRun = lv < 15 ? 6 : 5
    }
}

public enum SortGenerator {
    public static func trials(config: SortConfig, rng: inout SeededRNG) -> [SortTrial] {
        var out: [SortTrial] = []
        var rule = config.rules.first ?? .category
        var lastItem = ""
        for i in 0..<config.trials {
            var changed = false
            if config.mode == .sortSwitch && i > 0 {
                let shouldSwitch: Bool
                if let every = config.switchEvery { shouldSwitch = i % every == 0 } else { shouldSwitch = rng.chance(config.randomSwitchProb) }
                if shouldSwitch {
                    let others = config.rules.filter { $0 != rule }
                    if let next = others.randomElement(using: &rng) { rule = next; changed = true }
                }
            }
            var item = SortCatalog.all.randomElement(using: &rng)!
            while item.id == lastItem { item = SortCatalog.all.randomElement(using: &rng)! }
            lastItem = item.id
            let price: Int
            let tint: TintChoice
            if config.mode == .sortHidden {
                // 三个属性各不相同，答案能唯一反映用了哪条规则
                let c = item.category.rawValue
                let rest = [0, 1, 2].filter { $0 != c }.shuffled(using: &rng)
                let tier = PriceTier(rawValue: rest[0])!
                price = rng.int(in: tier.range)
                tint = TintChoice(rawValue: rest[1])!
            } else {
                let tier = PriceTier.allCases.randomElement(using: &rng)!
                price = rng.int(in: tier.range)
                tint = TintChoice.allCases.randomElement(using: &rng)!
            }
            out.append(SortTrial(item: item, price: price, tint: tint, rule: rule, ruleChanged: changed))
        }
        return out
    }
}

/// 隐藏规则引擎（威斯康星卡片分类）
public struct HiddenRuleEngine: Sendable {
    public private(set) var rule: SortRule
    public private(set) var previousRule: SortRule?
    public private(set) var streak = 0
    public private(set) var categoriesDone = 0
    public private(set) var perseverativeErrors = 0
    public private(set) var errors = 0
    public let runLength: Int

    public init(runLength: Int, rng: inout SeededRNG) {
        self.runLength = runLength
        self.rule = SortRule.allCases.randomElement(using: &rng)!
    }

    /// 返回是否正确；连对达到 runLength 后换规则
    public mutating func respond(bucket: Int?, trial: SortTrial, rng: inout SeededRNG) -> Bool {
        let correct = bucket == trial.answer(for: rule)
        if correct {
            streak += 1
            if streak >= runLength {
                categoriesDone += 1
                streak = 0
                previousRule = rule
                let others = SortRule.allCases.filter { $0 != rule }
                rule = others.randomElement(using: &rng)!
            }
        } else {
            errors += 1
            streak = 0
            if let prev = previousRule, let b = bucket, b == trial.answer(for: prev) {
                perseverativeErrors += 1
            }
        }
        return correct
    }
}
