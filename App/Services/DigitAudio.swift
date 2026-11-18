import AVFoundation
import Foundation

/// 听数字的声音引擎：
/// - 用系统中文语音把每个数字渲染成音频，按精确间隔排进时间线
/// - 鸡尾酒会模式再叠一条降调、偏到另一侧的干扰声音
/// - 背景是程序合成的「人群嘈杂声」
final class DigitAudio {
    static let digitWords = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]

    private let engine = AVAudioEngine()
    private let targetPlayer = AVAudioPlayerNode()
    private let distractorPlayer = AVAudioPlayerNode()
    private let pitch = AVAudioUnitTimePitch()
    private var noiseNode: AVAudioSourceNode?
    private let noise = BabbleNoise(sampleRate: 44_100)
    private let renderSynth = AVSpeechSynthesizer()
    private let speakSynth = AVSpeechSynthesizer()
    private let format: AVAudioFormat
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var prepared = false

    init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    }

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)

        let state = noise
        let src = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            state.render(abl, frames: Int(frameCount))
            return noErr
        }
        noiseNode = src
        engine.attach(src)
        engine.attach(targetPlayer)
        engine.attach(distractorPlayer)
        engine.attach(pitch)
        let mixer = engine.mainMixerNode
        engine.connect(src, to: mixer, format: format)
        engine.connect(targetPlayer, to: mixer, format: format)
        engine.connect(distractorPlayer, to: pitch, format: format)
        engine.connect(pitch, to: mixer, format: format)
        pitch.pitch = -650
        pitch.rate = 1.0
        targetPlayer.pan = 0.3
        distractorPlayer.pan = -0.45
        engine.prepare()
        try? engine.start()
    }

    func stop() {
        noise.amplitude = 0
        targetPlayer.stop()
        distractorPlayer.stop()
        speakSynth.stopSpeaking(at: .immediate)
    }

    func shutdown() {
        stop()
        engine.stop()
    }

    var voice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "zh-CN") ?? AVSpeechSynthesisVoice(language: "zh-TW")
    }

    /// 播放一组数字。onDigit(i) 在第 i 个目标数字开始时回调（主线程）
    func play(target: [Int], distractor: [Int]?, interval: Double, noiseLevel: Double,
              distractorVolume: Double, rate: Float, onDigit: @escaping (Int) -> Void) async {
        prepare()
        if !engine.isRunning { try? engine.start() }
        noise.amplitude = Float(noiseLevel) * 0.22

        var targetClips: [AVAudioPCMBuffer] = []
        for d in target {
            if let b = await clip(d, rate: rate) { targetClips.append(b) }
        }
        let rendered = targetClips.count == target.count && !target.isEmpty

        // 先让噪音铺垫半秒
        try? await Task.sleep(nanoseconds: 500_000_000)

        if rendered, let track = mix(clips: targetClips, interval: interval, offset: 0) {
            var distractorTrack: AVAudioPCMBuffer?
            if let distractor {
                var clips: [AVAudioPCMBuffer] = []
                for d in distractor { if let b = await clip(d, rate: rate) { clips.append(b) } }
                if clips.count == distractor.count {
                    distractorTrack = mix(clips: clips, interval: interval, offset: interval * 0.45)
                }
            }
            targetPlayer.volume = 1
            distractorPlayer.volume = Float(distractorVolume)
            targetPlayer.scheduleBuffer(track, at: nil, options: [], completionHandler: nil)
            if let dt = distractorTrack { distractorPlayer.scheduleBuffer(dt, at: nil, options: [], completionHandler: nil) }
            targetPlayer.play()
            if distractorTrack != nil { distractorPlayer.play() }
            for i in target.indices {
                await MainActor.run { onDigit(i) }
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
        } else {
            // 兜底：直接朗读（没有干扰声）
            for (i, d) in target.enumerated() {
                await MainActor.run { onDigit(i) }
                let u = AVSpeechUtterance(string: Self.digitWords[d])
                u.voice = voice
                u.rate = rate
                speakSynth.speak(u)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
        }
        noise.amplitude = 0
    }

    /// 预先渲染 0–9，第一轮不卡顿
    func warmUp(rate: Float) async {
        prepare()
        for d in 0...9 { _ = await clip(d, rate: rate) }
    }

    // MARK: - 渲染

    private func clip(_ digit: Int, rate: Float) async -> AVAudioPCMBuffer? {
        let key = "\(digit)-\(rate)"
        if let c = cache[key] { return c }
        let utterance = AVSpeechUtterance(string: Self.digitWords[digit])
        utterance.voice = voice
        utterance.rate = rate
        utterance.prefersAssistiveTechnologySettings = false
        let collector = BufferCollector()
        let buffers: [AVAudioPCMBuffer] = await withCheckedContinuation { cont in
            collector.continuation = cont
            renderSynth.write(utterance) { buffer in
                if let pcm = buffer as? AVAudioPCMBuffer, pcm.frameLength > 0 {
                    collector.append(pcm)
                } else {
                    collector.finish()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { collector.finish() }
        }
        guard !buffers.isEmpty else { return nil }
        let converted = buffers.compactMap { Self.convert($0, to: format) }
        guard let joined = Self.concat(converted, format: format), let trimmed = Self.trim(joined, format: format) else { return nil }
        cache[key] = trimmed
        return trimmed
    }

    private func mix(clips: [AVAudioPCMBuffer], interval: Double, offset: Double) -> AVAudioPCMBuffer? {
        let sr = format.sampleRate
        let longest = clips.map { Int($0.frameLength) }.max() ?? 0
        let total = Int((Double(clips.count - 1) * interval + offset) * sr) + longest + Int(0.2 * sr)
        guard total > 0, let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let dst = out.floatChannelData?[0] else { return nil }
        out.frameLength = AVAudioFrameCount(total)
        for i in 0..<total { dst[i] = 0 }
        for (i, clip) in clips.enumerated() {
            guard let src = clip.floatChannelData?[0] else { continue }
            let start = Int((Double(i) * interval + offset) * sr)
            let n = Int(clip.frameLength)
            for k in 0..<n where start + k < total { dst[start + k] += src[k] }
        }
        return out
    }

    static func convert(_ input: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if input.format == format { return input }
        guard let converter = AVAudioConverter(from: input.format, to: format) else { return nil }
        let ratio = format.sampleRate / input.format.sampleRate
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio + 2048)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var consumed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return input
        }
        if status == .error || out.frameLength == 0 { return nil }
        return out
    }

    static func concat(_ buffers: [AVAudioPCMBuffer], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let total = buffers.reduce(0) { $0 + Int($1.frameLength) }
        guard total > 0, let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let dst = out.floatChannelData?[0] else { return nil }
        var pos = 0
        for b in buffers {
            guard let src = b.floatChannelData?[0] else { continue }
            let n = Int(b.frameLength)
            for k in 0..<n { dst[pos + k] = src[k] }
            pos += n
        }
        out.frameLength = AVAudioFrameCount(pos)
        return out
    }

    /// 去掉首尾静音，让间隔更精确
    static func trim(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let data = buffer.floatChannelData?[0] else { return nil }
        let n = Int(buffer.frameLength)
        var first = 0
        while first < n && abs(data[first]) < 0.008 { first += 1 }
        var last = n - 1
        while last > first && abs(data[last]) < 0.008 { last -= 1 }
        let length = max(1, last - first + 1)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(length)),
              let dst = out.floatChannelData?[0] else { return nil }
        for k in 0..<length { dst[k] = first + k < n ? data[first + k] : 0 }
        out.frameLength = AVAudioFrameCount(length)
        return out
    }
}

/// 收集 write 回调里的音频块，只 resume 一次
private final class BufferCollector: @unchecked Sendable {
    var continuation: CheckedContinuation<[AVAudioPCMBuffer], Never>?
    private var buffers: [AVAudioPCMBuffer] = []
    private let lock = NSLock()
    private var done = false

    func append(_ b: AVAudioPCMBuffer) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        // 复制一份，回调结束后系统可能复用缓冲区
        if let copy = AVAudioPCMBuffer(pcmFormat: b.format, frameCapacity: b.frameLength) {
            copy.frameLength = b.frameLength
            let channels = Int(b.format.channelCount)
            if let s = b.floatChannelData, let d = copy.floatChannelData {
                for c in 0..<channels { for k in 0..<Int(b.frameLength) { d[c][k] = s[c][k] } }
                buffers.append(copy)
            } else if let s = b.int16ChannelData, let d = copy.int16ChannelData {
                for c in 0..<channels { for k in 0..<Int(b.frameLength) { d[c][k] = s[c][k] } }
                buffers.append(copy)
            } else if let s = b.int32ChannelData, let d = copy.int32ChannelData {
                for c in 0..<channels { for k in 0..<Int(b.frameLength) { d[c][k] = s[c][k] } }
                buffers.append(copy)
            }
        }
    }

    func finish() {
        lock.lock()
        guard !done else { lock.unlock(); return }
        done = true
        let result = buffers
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(returning: result)
    }
}

/// 合成的人群嘈杂声：几路带通噪声，按音节节奏起伏
final class BabbleNoise: @unchecked Sendable {
    var amplitude: Float = 0

    private struct Voice {
        var a: Float
        var b: Float
        var lpA: Float = 0
        var lpB: Float = 0
        var env: Float = 0
        var target: Float = 0
        var countdown = 0
        var gain: Float
    }

    private var voices: [Voice]
    private var seed: UInt32 = 0x1234_5678
    private var current: Float = 0
    private let sampleRate: Float

    init(sampleRate: Double) {
        self.sampleRate = Float(sampleRate)
        func alpha(_ fc: Float) -> Float { 1 - exp(-2 * Float.pi * fc / Float(sampleRate)) }
        voices = [
            Voice(a: alpha(1900), b: alpha(260), gain: 1.0),
            Voice(a: alpha(1300), b: alpha(180), gain: 0.9),
            Voice(a: alpha(2600), b: alpha(420), gain: 0.7),
            Voice(a: alpha(900), b: alpha(120), gain: 0.8)
        ]
    }

    private func rand() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(seed >> 8) / Float(1 << 24) * 2 - 1
    }

    func render(_ abl: UnsafeMutableAudioBufferListPointer, frames: Int) {
        guard let first = abl.first, let out = first.mData?.assumingMemoryBound(to: Float.self) else { return }
        let targetAmp = amplitude
        for i in 0..<frames {
            current += (targetAmp - current) * 0.0005
            var s: Float = 0
            if current > 0.0001 {
                for v in voices.indices {
                    let n = rand()
                    voices[v].lpA += voices[v].a * (n - voices[v].lpA)
                    voices[v].lpB += voices[v].b * (n - voices[v].lpB)
                    if voices[v].countdown <= 0 {
                        let r = (rand() + 1) / 2
                        voices[v].target = r < 0.25 ? 0.05 : 0.3 + r * 0.9
                        voices[v].countdown = Int(sampleRate * (0.08 + (rand() + 1) * 0.11))
                    }
                    voices[v].countdown -= 1
                    voices[v].env += (voices[v].target - voices[v].env) * 0.0016
                    s += (voices[v].lpA - voices[v].lpB) * voices[v].env * voices[v].gain
                }
            }
            out[i] = s * current * 2.4
        }
        for k in 1..<max(1, abl.count) {
            if let dst = abl[k].mData?.assumingMemoryBound(to: Float.self) {
                for i in 0..<frames { dst[i] = out[i] }
            }
        }
    }
}
