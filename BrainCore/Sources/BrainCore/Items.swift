import Foundation

public enum ItemHue: String, Codable, Sendable, Hashable, CaseIterable {
    case gold, red, blue, green, purple, gray, orange, pink, brown, cream
}

public enum ItemCategory: String, Codable, Sendable, Hashable, CaseIterable {
    case vehicle = "交通"
    case animal = "动物"
    case food = "食物"
    case home = "家居"
    case device = "电器"
    case stationery = "文具"
    case sport = "运动"
    case nature = "自然"
    case wear = "服饰"
    case music = "乐器"
    case tool = "工具"
}

/// 记忆清单 / 串成故事用到的物品
public struct ObjectItem: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String
    public let category: ItemCategory
    public let hue: ItemHue
    /// 画面感短语，用于示范故事
    public let image: String

    public init(_ id: String, _ name: String, _ symbol: String, _ category: ItemCategory, _ hue: ItemHue, _ image: String) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.category = category
        self.hue = hue
        self.image = image
    }
}

public enum ItemCatalog {
    public static let all: [ObjectItem] = [
        ObjectItem("car", "轿车", "car.fill", .vehicle, .gray, "一辆银色轿车"),
        ObjectItem("bus", "公交车", "bus.fill", .vehicle, .green, "一辆绿色公交车"),
        ObjectItem("train", "火车", "tram.fill", .vehicle, .green, "一列绿皮火车"),
        ObjectItem("plane", "飞机", "airplane", .vehicle, .blue, "一架银白飞机"),
        ObjectItem("bike", "自行车", "bicycle", .vehicle, .red, "一辆红色自行车"),
        ObjectItem("boat", "帆船", "sailboat.fill", .vehicle, .cream, "一艘白帆小船"),
        ObjectItem("scooter", "滑板车", "scooter", .vehicle, .orange, "一辆橙色滑板车"),
        ObjectItem("cat", "猫", "cat.fill", .animal, .orange, "一只橘猫"),
        ObjectItem("dog", "狗", "dog.fill", .animal, .brown, "一只棕色小狗"),
        ObjectItem("fish", "鱼", "fish.fill", .animal, .blue, "一条蓝色的鱼"),
        ObjectItem("bird", "小鸟", "bird.fill", .animal, .gold, "一只黄色小鸟"),
        ObjectItem("turtle", "乌龟", "tortoise.fill", .animal, .green, "一只慢吞吞的乌龟"),
        ObjectItem("rabbit", "兔子", "hare.fill", .animal, .cream, "一只白兔"),
        ObjectItem("ladybug", "瓢虫", "ladybug.fill", .animal, .red, "一只七星瓢虫"),
        ObjectItem("ant", "蚂蚁", "ant.fill", .animal, .brown, "一只大蚂蚁"),
        ObjectItem("banana", "香蕉", "moon.fill", .food, .gold, "一根弯弯的香蕉"),
        ObjectItem("carrot", "胡萝卜", "carrot.fill", .food, .orange, "一根胡萝卜"),
        ObjectItem("cake", "蛋糕", "birthday.cake.fill", .food, .pink, "一块草莓蛋糕"),
        ObjectItem("coffee", "咖啡", "cup.and.saucer.fill", .food, .brown, "一杯热咖啡"),
        ObjectItem("popcorn", "爆米花", "popcorn.fill", .food, .red, "一桶爆米花"),
        ObjectItem("wine", "红酒", "wineglass.fill", .food, .red, "一杯红酒"),
        ObjectItem("bread", "面包", "takeoutbag.and.cup.and.straw.fill", .food, .brown, "一袋刚出炉的面包"),
        ObjectItem("lamp", "台灯", "lamp.desk.fill", .home, .gold, "一盏暖黄台灯"),
        ObjectItem("sofa", "沙发", "sofa.fill", .home, .red, "一张红丝绒沙发"),
        ObjectItem("bed", "床", "bed.double.fill", .home, .blue, "一张软软的大床"),
        ObjectItem("chair", "椅子", "chair.fill", .home, .brown, "一把木椅子"),
        ObjectItem("key", "钥匙", "key.fill", .home, .gold, "一把金钥匙"),
        ObjectItem("umbrella", "雨伞", "umbrella.fill", .home, .gray, "一把灰色雨伞"),
        ObjectItem("alarm", "闹钟", "alarm.fill", .home, .red, "一个叮铃作响的闹钟"),
        ObjectItem("tv", "电视", "tv.fill", .device, .gray, "一台老电视"),
        ObjectItem("phone", "手机", "iphone", .device, .gray, "一部手机"),
        ObjectItem("headphones", "耳机", "headphones", .device, .purple, "一副大耳机"),
        ObjectItem("camera", "相机", "camera.fill", .device, .gray, "一台胶片相机"),
        ObjectItem("laptop", "电脑", "laptopcomputer", .device, .gray, "一台笔记本电脑"),
        ObjectItem("bulb", "灯泡", "lightbulb.fill", .device, .gold, "一只发光的灯泡"),
        ObjectItem("game", "手柄", "gamecontroller.fill", .device, .purple, "一个游戏手柄"),
        ObjectItem("pencil", "铅笔", "pencil", .stationery, .gold, "一支黄色铅笔"),
        ObjectItem("book", "书", "book.fill", .stationery, .blue, "一本厚厚的书"),
        ObjectItem("scissors", "剪刀", "scissors", .stationery, .red, "一把红柄剪刀"),
        ObjectItem("ruler", "尺子", "ruler.fill", .stationery, .gold, "一把长尺子"),
        ObjectItem("clip", "回形针", "paperclip", .stationery, .gray, "一枚回形针"),
        ObjectItem("brush", "画笔", "paintbrush.fill", .stationery, .purple, "一支沾满颜料的画笔"),
        ObjectItem("football", "足球", "soccerball", .sport, .cream, "一个黑白足球"),
        ObjectItem("basketball", "篮球", "basketball.fill", .sport, .orange, "一个篮球"),
        ObjectItem("tennis", "网球拍", "tennis.racket", .sport, .green, "一支网球拍"),
        ObjectItem("dumbbell", "哑铃", "dumbbell.fill", .sport, .gray, "一对沉甸甸的哑铃"),
        ObjectItem("trophy", "奖杯", "trophy.fill", .sport, .gold, "一座金奖杯"),
        ObjectItem("flag", "旗子", "flag.fill", .sport, .red, "一面红旗"),
        ObjectItem("tree", "大树", "tree.fill", .nature, .green, "一棵大树"),
        ObjectItem("mountain", "高山", "mountain.2.fill", .nature, .gray, "一座雪山"),
        ObjectItem("sun", "太阳", "sun.max.fill", .nature, .orange, "一轮红太阳"),
        ObjectItem("cloud", "云朵", "cloud.fill", .nature, .cream, "一朵白云"),
        ObjectItem("snow", "雪花", "snowflake", .nature, .blue, "一片大雪花"),
        ObjectItem("flame", "火焰", "flame.fill", .nature, .orange, "一团火焰"),
        ObjectItem("leaf", "树叶", "leaf.fill", .nature, .green, "一片绿叶"),
        ObjectItem("shirt", "T恤", "tshirt.fill", .wear, .blue, "一件蓝色T恤"),
        ObjectItem("crown", "皇冠", "crown.fill", .wear, .gold, "一顶金皇冠"),
        ObjectItem("glasses", "眼镜", "eyeglasses", .wear, .gray, "一副圆眼镜"),
        ObjectItem("bag", "手提包", "handbag.fill", .wear, .pink, "一个粉色手提包"),
        ObjectItem("guitar", "吉他", "guitars.fill", .music, .brown, "一把木色吉他"),
        ObjectItem("piano", "钢琴", "pianokeys", .music, .cream, "一架钢琴"),
        ObjectItem("note", "音符", "music.note", .music, .purple, "一串跳动的音符"),
        ObjectItem("bell", "铃铛", "bell.fill", .music, .gold, "一只铜铃铛"),
        ObjectItem("hammer", "锤子", "hammer.fill", .tool, .gray, "一把铁锤"),
        ObjectItem("wrench", "扳手", "wrench.fill", .tool, .gray, "一把扳手"),
        ObjectItem("flashlight", "手电筒", "flashlight.on.fill", .tool, .gold, "一支亮着的手电筒"),
        ObjectItem("magnifier", "放大镜", "magnifyingglass", .tool, .gray, "一个放大镜"),
        ObjectItem("gift", "礼物", "gift.fill", .home, .red, "一个红色礼物盒"),
        ObjectItem("balloon", "气球", "balloon.fill", .nature, .pink, "一只粉色气球"),
        ObjectItem("teddy", "玩具熊", "teddybear.fill", .home, .brown, "一只玩具熊")
    ]

    public static func item(_ id: String) -> ObjectItem? { all.first { $0.id == id } }

    /// 尽量跨类别地抽取 count 个物品
    public static func pick(_ count: Int, rng: inout SeededRNG, excluding: Set<String> = []) -> [ObjectItem] {
        var pool = all.filter { !excluding.contains($0.id) }.shuffled(using: &rng)
        var result: [ObjectItem] = []
        var usedCategories: [ItemCategory: Int] = [:]
        while result.count < count && !pool.isEmpty {
            let minUse = usedCategories.values.min() ?? 0
            let index = pool.firstIndex { (usedCategories[$0.category] ?? 0) <= minUse } ?? 0
            let item = pool.remove(at: index)
            result.append(item)
            usedCategories[item.category, default: 0] += 1
            if usedCategories.count < ItemCategory.allCases.count {
                for c in ItemCategory.allCases where usedCategories[c] == nil { usedCategories[c] = 0 }
            }
        }
        return result
    }

    /// 干扰项：sameCategory 时优先同类别（更难）
    public static func distractors(for study: [ObjectItem], count: Int, sameCategory: Bool, rng: inout SeededRNG) -> [ObjectItem] {
        let used = Set(study.map(\.id))
        var pool = all.filter { !used.contains($0.id) }.shuffled(using: &rng)
        if sameCategory {
            let cats = Set(study.map(\.category))
            pool.sort { (cats.contains($0.category) ? 0 : 1) < (cats.contains($1.category) ? 0 : 1) }
        }
        return Array(pool.prefix(count))
    }
}
