import Foundation

/// 7 个脑训练
public enum TrainingKind: String, CaseIterable, Codable, Identifiable, Sendable, Hashable {
    case schulte, stroop, memory, digits, mirror, sorting, story

    public var id: String { rawValue }

    /// 1...7
    public var number: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }

    public var ordinal: String {
        ["第一个", "第二个", "第三个", "第四个", "第五个", "第六个", "第七个"][number - 1]
    }

    public var title: String {
        switch self {
        case .schulte: return "舒尔特方格"
        case .stroop: return "斯特鲁普训练"
        case .memory: return "记忆清单"
        case .digits: return "听数字"
        case .mirror: return "镜像画"
        case .sorting: return "快速分类"
        case .story: return "串成故事"
        }
    }

    /// 视频里右上角的研究出处小标签
    public var citation: String {
        switch self {
        case .schulte: return "Walter Schulte · 舒尔特方格"
        case .stroop: return "Stroop 1935 · 斯特鲁普效应"
        case .memory: return "Miller 1956 · 神奇的数字 7±2"
        case .digits: return "Cherry 1953 · 鸡尾酒会效应"
        case .mirror: return "胼胝体 · 运动皮层 · 小脑"
        case .sorting: return "Wisconsin 卡片分类测验 · 认知灵活性"
        case .story: return "Bower & Clark 1969 · 叙事串联法"
        }
    }

    /// 雷达图维度
    public var dimension: String {
        switch self {
        case .schulte: return "视觉广度"
        case .stroop: return "抑制控制"
        case .memory: return "工作记忆"
        case .digits: return "听觉注意"
        case .mirror: return "双手协调"
        case .sorting: return "认知灵活"
        case .story: return "联想记忆"
        }
    }

    /// 一句话规则
    public var tagline: String {
        switch self {
        case .schulte: return "从1开始，按顺序找到最后一个"
        case .stroop: return "不读字，只说它的颜色"
        case .memory: return "记住每样东西，还有顺序"
        case .digits: return "背景再吵，记住数字和顺序"
        case .mirror: return "双手一起，方向相反同时画"
        case .sorting: return "看到东西，马上说出它属于哪一类"
        case .story: return "几样东西，编进一个画面"
        }
    }

    /// 字幕式规则说明，[ ] 内为金色高亮
    public var rules: [String] {
        switch self {
        case .schulte:
            return ["数字[打乱顺序]，铺满整个方格",
                    "从[1]开始，按顺序一个个找",
                    "眼睛盯住中间，用[余光]去找",
                    "目标时间内找完，就算[过关]"]
        case .stroop:
            return ["不读字，只说它的[颜色]",
                    "那半秒的犹豫，是大脑在和自己[较劲]",
                    "跟着金框，[又快又准]",
                    "这练的是大脑的[刹车]"]
        case .memory:
            return ["记住每样东西，还有[顺序]",
                    "不用记细节，只记[类别]和顺序",
                    "收起来以后，按顺序找回来",
                    "能从7个加到[9个]，还能更多"]
        case .digits:
            return ["背景再吵，也要记住[数字和顺序]",
                    "听完，再完整[复述]一遍",
                    "吵闹里抓住想听的，这叫[鸡尾酒会效应]",
                    "位数多一点、噪音大一点、[倒着]复述"]
        case .mirror:
            return ["[双手]一起，各画一边",
                    "方向相反，[同时]画",
                    "先画圆，再画心，熟练了画[复杂图案]",
                    "左右脑一起[协作]"]
        case .sorting:
            return ["看到东西，马上说出它属于[哪一类]",
                    "全对了？再加一条规则：[价格]",
                    "规则随时会变，[马上切换]",
                    "最难的一关：规则[不告诉你]"]
        case .story:
            return ["几样东西，编进[一个画面]",
                    "画面越[具体]，记得越牢",
                    "编成故事的人记住了[93%]，死记的只有13%",
                    "过一阵再考你，看故事[还在不在]"]
        }
    }

    /// 生活收益（视频原话）
    public var benefit: String {
        switch self {
        case .schulte: return "练久了，读书能[一眼一行]"
        case .stroop: return "急的时候，也能[先停一秒]"
        case .memory: return "买东西，[清单]就在脑子里"
        case .digits: return "再吵，也能听清[那句广播]"
        case .mirror: return "打字、弹琴、写字，[手更听话]"
        case .sorting: return "规则一变，也能[马上切换]"
        case .story: return "名字、数字、新知识，都能[编进故事]"
        }
    }

    public var symbol: String {
        switch self {
        case .schulte: return "square.grid.3x3.fill"
        case .stroop: return "paintpalette.fill"
        case .memory: return "list.number"
        case .digits: return "headphones"
        case .mirror: return "hand.draw.fill"
        case .sorting: return "tray.2.fill"
        case .story: return "book.fill"
        }
    }

    public var modes: [ModeID] {
        ModeID.allCases.filter { $0.kind == self }
    }
}

/// 每个训练下的玩法
public enum ModeID: String, Codable, CaseIterable, Identifiable, Sendable, Hashable {
    case schulteClassic, schulteReverse, schulteLetters, schultePoem, schulteDynamic, schulteGorbov
    case stroopColor, stroopCount, stroopSwitch, stroopDirection
    case memoryOrdered, memoryReverse, memoryProbe, memoryChange
    case digitsForward, digitsBackward, digitsCocktail, digitsSorted
    case mirrorSymmetric, mirrorRhythm, mirrorParallel, mirrorDifferent
    case sortSingle, sortSwitch, sortHidden
    case storyChain, storyCue, storyNumber, storyDelayed

    public var id: String { rawValue }

    public var kind: TrainingKind {
        switch self {
        case .schulteClassic, .schulteReverse, .schulteLetters, .schultePoem, .schulteDynamic, .schulteGorbov: return .schulte
        case .stroopColor, .stroopCount, .stroopSwitch, .stroopDirection: return .stroop
        case .memoryOrdered, .memoryReverse, .memoryProbe, .memoryChange: return .memory
        case .digitsForward, .digitsBackward, .digitsCocktail, .digitsSorted: return .digits
        case .mirrorSymmetric, .mirrorRhythm, .mirrorParallel, .mirrorDifferent: return .mirror
        case .sortSingle, .sortSwitch, .sortHidden: return .sorting
        case .storyChain, .storyCue, .storyNumber, .storyDelayed: return .story
        }
    }

    public var title: String {
        switch self {
        case .schulteClassic: return "经典"
        case .schulteReverse: return "倒数"
        case .schulteLetters: return "字母"
        case .schultePoem: return "诗句"
        case .schulteDynamic: return "流动"
        case .schulteGorbov: return "红金交替"
        case .stroopColor: return "说颜色"
        case .stroopCount: return "数个数"
        case .stroopSwitch: return "规则切换"
        case .stroopDirection: return "辨方位"
        case .memoryOrdered: return "顺序回忆"
        case .memoryReverse: return "倒序回忆"
        case .memoryProbe: return "定位提问"
        case .memoryChange: return "找变化"
        case .digitsForward: return "顺背"
        case .digitsBackward: return "倒背"
        case .digitsCocktail: return "鸡尾酒会"
        case .digitsSorted: return "排序背"
        case .mirrorSymmetric: return "镜像对称"
        case .mirrorRhythm: return "复合节奏"
        case .mirrorParallel: return "同向平移"
        case .mirrorDifferent: return "左右异形"
        case .sortSingle: return "按类别"
        case .sortSwitch: return "规则切换"
        case .sortHidden: return "隐藏规则"
        case .storyChain: return "串成故事"
        case .storyCue: return "接龙提问"
        case .storyNumber: return "数字编码"
        case .storyDelayed: return "延迟回忆"
        }
    }

    public var detail: String {
        switch self {
        case .schulteClassic: return "从小到大，依次点出每个数字"
        case .schulteReverse: return "从最大的数，倒着找回 1"
        case .schulteLetters: return "按 A、B、C… 字母顺序找"
        case .schultePoem: return "按古诗的字序找字，混着干扰字"
        case .schulteDynamic: return "每点对一个，整盘重新打乱"
        case .schulteGorbov: return "金色正着数、红色倒着数，交替进行"
        case .stroopColor: return "跟着金框，说出字的颜色"
        case .stroopCount: return "回答有几个数字，而不是数字是几"
        case .stroopSwitch: return "金框说颜色，白框读字，随时切换"
        case .stroopDirection: return "回答字出现在哪个方位，不管字义"
        case .memoryOrdered: return "逐个看一遍，按顺序找回来"
        case .memoryReverse: return "逐个看一遍，倒着顺序找回来"
        case .memoryProbe: return "第几个是什么？它排第几？"
        case .memoryChange: return "前后两次对比，找出变了的位置"
        case .digitsForward: return "听完，按原顺序输入"
        case .digitsBackward: return "听完，倒着输入"
        case .digitsCocktail: return "两个声音同时报数，只记高音那个"
        case .digitsSorted: return "听完，从小到大重新排好输入"
        case .mirrorSymmetric: return "左右手方向相反，同时画"
        case .mirrorRhythm: return "左手和右手，按不同拍子同时敲"
        case .mirrorParallel: return "左右手方向相同，同时画"
        case .mirrorDifferent: return "左手一个图形，右手另一个图形"
        case .sortSingle: return "食品、文具、日用品，越快越好"
        case .sortSwitch: return "类别、价格、颜色，规则随时会变"
        case .sortHidden: return "规则不告诉你，靠对错去猜，猜中还会偷偷换"
        case .storyChain: return "编成故事，再按顺序找回来"
        case .storyCue: return "问你某样东西的前一个、后一个"
        case .storyNumber: return "把一长串数字变成画面记住"
        case .storyDelayed: return "上次编的故事，现在还记得吗"
        }
    }

    /// 该训练的熟练度（各玩法最高等级）达到多少解锁
    public var unlockMastery: Int {
        switch self {
        case .schulteClassic: return 1
        case .schulteReverse: return 3
        case .schulteLetters: return 5
        case .schultePoem: return 8
        case .schulteDynamic: return 11
        case .schulteGorbov: return 15
        case .stroopColor: return 1
        case .stroopCount: return 3
        case .stroopSwitch: return 5
        case .stroopDirection: return 8
        case .memoryOrdered: return 1
        case .memoryReverse: return 4
        case .memoryProbe: return 7
        case .memoryChange: return 10
        case .digitsForward: return 1
        case .digitsBackward: return 4
        case .digitsCocktail: return 6
        case .digitsSorted: return 9
        case .mirrorSymmetric: return 1
        case .mirrorRhythm: return 3
        case .mirrorParallel: return 6
        case .mirrorDifferent: return 10
        case .sortSingle: return 1
        case .sortSwitch: return 4
        case .sortHidden: return 9
        case .storyChain: return 1
        case .storyCue: return 4
        case .storyNumber: return 7
        case .storyDelayed: return 1
        }
    }

    /// 是否计入每日训练（延迟回忆依赖历史，不进每日）
    public var isDailyEligible: Bool { self != .storyDelayed }
}
