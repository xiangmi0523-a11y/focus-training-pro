import Foundation

public struct Poem: Sendable, Hashable {
    public let title: String
    public let author: String
    public let lines: [String]

    public var characters: [String] { lines.joined().map { String($0) } }
}

public enum PoemLibrary {
    /// 五言绝句（唐诗）
    public static let fiveCharacter: [Poem] = [
        Poem(title: "静夜思", author: "李白", lines: ["床前明月光", "疑是地上霜", "举头望明月", "低头思故乡"]),
        Poem(title: "春晓", author: "孟浩然", lines: ["春眠不觉晓", "处处闻啼鸟", "夜来风雨声", "花落知多少"]),
        Poem(title: "登鹳雀楼", author: "王之涣", lines: ["白日依山尽", "黄河入海流", "欲穷千里目", "更上一层楼"]),
        Poem(title: "相思", author: "王维", lines: ["红豆生南国", "春来发几枝", "愿君多采撷", "此物最相思"]),
        Poem(title: "江雪", author: "柳宗元", lines: ["千山鸟飞绝", "万径人踪灭", "孤舟蓑笠翁", "独钓寒江雪"]),
        Poem(title: "鹿柴", author: "王维", lines: ["空山不见人", "但闻人语响", "返景入深林", "复照青苔上"]),
        Poem(title: "寻隐者不遇", author: "贾岛", lines: ["松下问童子", "言师采药去", "只在此山中", "云深不知处"]),
        Poem(title: "悯农", author: "李绅", lines: ["锄禾日当午", "汗滴禾下土", "谁知盘中餐", "粒粒皆辛苦"]),
        Poem(title: "独坐敬亭山", author: "李白", lines: ["众鸟高飞尽", "孤云独去闲", "相看两不厌", "只有敬亭山"])
    ]

    /// 七言绝句（唐诗）
    public static let sevenCharacter: [Poem] = [
        Poem(title: "望庐山瀑布", author: "李白", lines: ["日照香炉生紫烟", "遥看瀑布挂前川", "飞流直下三千尺", "疑是银河落九天"]),
        Poem(title: "早发白帝城", author: "李白", lines: ["朝辞白帝彩云间", "千里江陵一日还", "两岸猿声啼不住", "轻舟已过万重山"]),
        Poem(title: "枫桥夜泊", author: "张继", lines: ["月落乌啼霜满天", "江枫渔火对愁眠", "姑苏城外寒山寺", "夜半钟声到客船"]),
        Poem(title: "山行", author: "杜牧", lines: ["远上寒山石径斜", "白云生处有人家", "停车坐爱枫林晚", "霜叶红于二月花"]),
        Poem(title: "绝句", author: "杜甫", lines: ["两个黄鹂鸣翠柳", "一行白鹭上青天", "窗含西岭千秋雪", "门泊东吴万里船"]),
        Poem(title: "出塞", author: "王昌龄", lines: ["秦时明月汉时关", "万里长征人未还", "但使龙城飞将在", "不教胡马度阴山"]),
        Poem(title: "凉州词", author: "王翰", lines: ["葡萄美酒夜光杯", "欲饮琵琶马上催", "醉卧沙场君莫笑", "古来征战几人回"])
    ]

    public static let decoys: [String] = "天地风雨雪花鸟虫鱼草木石金玉琴书剑酒茶灯桥舟城门窗竹梅兰菊松柏秋冬夏晨暮烟霞星辰河海湖泉溪谷峰岭沙田园村市楼阁亭台宫殿车马".map { String($0) }
}

public struct SchulteConfig: Sendable {
    public let mode: ModeID
    public let level: Int
    public let size: Int
    public let targetTime: Double
    public let markFound: Bool
    public let shuffleOnTap: Bool

    public init(mode: ModeID, level: Int) {
        let lv = clamp(level, 1, LevelSystem.maxLevel)
        self.mode = mode
        self.level = lv
        var size: Int
        switch lv {
        case ..<4: size = 4
        case 4..<9: size = 5
        case 9..<15: size = 6
        default: size = 7
        }
        switch mode {
        case .schulteLetters: size = min(size, 5)
        case .schultePoem: size = lv <= 4 ? 4 : (lv <= 12 ? 5 : 6)
        case .schulteGorbov: size = max(size, 5)
        default: break
        }
        self.size = size
        let perCell = max(0.55, 1.45 - 0.035 * Double(lv))
        let factor: Double
        switch mode {
        case .schulteReverse: factor = 1.1
        case .schulteLetters: factor = 1.15
        case .schultePoem: factor = 1.4
        case .schulteDynamic: factor = 1.35
        case .schulteGorbov: factor = 1.7
        default: factor = 1.0
        }
        let cells = Double(size * size)
        self.targetTime = (cells * perCell * factor * 10).rounded() / 10
        self.markFound = lv < 6
        self.shuffleOnTap = mode == .schulteDynamic
    }
}

public struct SchulteCell: Identifiable, Sendable, Hashable {
    public enum Tint: Int, Sendable { case plain, gold, red }
    public let id: Int
    public let label: String
    public let tint: Tint
    public var found: Bool = false
    /// 诗句模式中的干扰字
    public let isDecoy: Bool

    public init(id: Int, label: String, tint: Tint = .plain, isDecoy: Bool = false) {
        self.id = id
        self.label = label
        self.tint = tint
        self.isDecoy = isDecoy
    }
}

public struct SchulteTarget: Sendable, Hashable {
    public let label: String
    public let tint: SchulteCell.Tint
}

public struct SchulteBoard: Sendable {
    public private(set) var cells: [SchulteCell]
    public let sequence: [SchulteTarget]
    public private(set) var progress: Int = 0
    public private(set) var errors: Int = 0
    public let poem: Poem?

    public var isComplete: Bool { progress >= sequence.count }
    public var nextTarget: SchulteTarget? { isComplete ? nil : sequence[progress] }

    public init(config: SchulteConfig, rng: inout SeededRNG) {
        let n = config.size * config.size
        var cells: [SchulteCell] = []
        var sequence: [SchulteTarget] = []
        var poem: Poem?
        switch config.mode {
        case .schulteReverse:
            cells = (1...n).map { SchulteCell(id: $0, label: "\($0)") }
            sequence = (1...n).reversed().map { SchulteTarget(label: "\($0)", tint: .plain) }
        case .schulteLetters:
            let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").prefix(n).map { String($0) }
            cells = letters.enumerated().map { SchulteCell(id: $0.offset, label: $0.element) }
            sequence = letters.map { SchulteTarget(label: $0, tint: .plain) }
        case .schultePoem:
            let p: Poem
            if config.size >= 6 {
                p = PoemLibrary.sevenCharacter.randomElement(using: &rng)!
            } else {
                p = PoemLibrary.fiveCharacter.randomElement(using: &rng)!
            }
            poem = p
            let chars = Array(p.characters.prefix(n == 16 ? 15 : p.characters.count))
            let poemSet = Set(p.characters)
            let decoyPool = PoemLibrary.decoys.filter { !poemSet.contains($0) }.shuffled(using: &rng)
            let decoyCount = max(0, n - chars.count)
            cells = chars.enumerated().map { SchulteCell(id: $0.offset, label: $0.element) }
            cells += decoyPool.prefix(decoyCount).enumerated().map {
                SchulteCell(id: 1000 + $0.offset, label: $0.element, isDecoy: true)
            }
            sequence = chars.map { SchulteTarget(label: $0, tint: .plain) }
        case .schulteGorbov:
            let goldCount = (n + 1) / 2
            let redCount = n / 2
            cells = (1...goldCount).map { SchulteCell(id: $0, label: "\($0)", tint: .gold) }
            cells += (1...max(1, redCount)).prefix(redCount).map { SchulteCell(id: 1000 + $0, label: "\($0)", tint: .red) }
            var seq: [SchulteTarget] = []
            var g = 1
            var r = redCount
            while g <= goldCount || r >= 1 {
                if g <= goldCount { seq.append(SchulteTarget(label: "\(g)", tint: .gold)); g += 1 }
                if r >= 1 { seq.append(SchulteTarget(label: "\(r)", tint: .red)); r -= 1 }
            }
            sequence = seq
        default:
            cells = (1...n).map { SchulteCell(id: $0, label: "\($0)") }
            sequence = (1...n).map { SchulteTarget(label: "\($0)", tint: .plain) }
        }
        cells.shuffle(using: &rng)
        self.cells = cells
        self.sequence = sequence
        self.poem = poem
    }

    /// 点击第 index 个格子，返回是否正确
    @discardableResult
    public mutating func tap(_ index: Int) -> Bool {
        guard index >= 0, index < cells.count, let target = nextTarget else { return false }
        let cell = cells[index]
        if !cell.found && !cell.isDecoy && cell.label == target.label && cell.tint == target.tint {
            cells[index].found = true
            progress += 1
            return true
        }
        errors += 1
        return false
    }

    /// 打乱所有格子的位置
    public mutating func reshuffle(rng: inout SeededRNG) {
        cells.shuffle(using: &rng)
    }

    /// 评分：时间（含错误罚时）越接近或低于目标分越高
    public static func evaluate(elapsed: Double, errors: Int, completed: Bool, config: SchulteConfig) -> (score: Int, outcome: Outcome, effective: Double) {
        let effective = elapsed + Double(errors)
        guard completed else { return (Int(clamp(40.0 * config.targetTime / max(effective, 0.1), 0, 40)), .fail, effective) }
        let ratio = config.targetTime / max(effective, 0.1)
        let score = Int(clamp(ratio * 85, 0, 100).rounded())
        let outcome: Outcome
        if effective <= config.targetTime * 0.8 && errors == 0 {
            outcome = .excellent
        } else if effective <= config.targetTime {
            outcome = .pass
        } else {
            outcome = .fail
        }
        return (score, outcome, effective)
    }
}
