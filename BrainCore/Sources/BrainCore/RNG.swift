import Foundation

/// 可复现的随机数（SplitMix64），用于出题、每日计划和测试。
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    public static func random() -> SeededRNG {
        SeededRNG(seed: UInt64.random(in: 0...UInt64.max))
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// 0..<upper
    public mutating func int(_ upper: Int) -> Int {
        guard upper > 1 else { return 0 }
        return Int(next() % UInt64(upper))
    }

    public mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + int(range.upperBound - range.lowerBound + 1)
    }

    public mutating func chance(_ p: Double) -> Bool {
        Double(next() % 1_000_000) / 1_000_000.0 < p
    }

    public mutating func double(in range: ClosedRange<Double>) -> Double {
        let u = Double(next() % 1_000_000) / 1_000_000.0
        return range.lowerBound + (range.upperBound - range.lowerBound) * u
    }
}

public func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
    min(max(value, lower), upper)
}
