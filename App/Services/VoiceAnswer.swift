import AVFoundation
import Foundation
import Speech
import BrainCore

/// 斯特鲁普的语音作答：说出颜色就算作答
final class VoiceAnswer {
    var colors: [InkColor] = InkColor.allCases
    var onColor: ((InkColor) -> Void)?
    var onHeard: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var consumed = 0
    private(set) var running = false

    static func requestPermission(_ completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(status == .authorized && granted) }
            }
        }
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    func start() -> Bool {
        stop()
        guard let recognizer, recognizer.isAvailable else { return false }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            req.contextualStrings = colors.map(\.name)
            request = req
            let input = audioEngine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            consumed = 0
            running = true
            task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                guard let self else { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    DispatchQueue.main.async { self.handle(text) }
                }
                if error != nil || (result?.isFinal ?? false) {
                    DispatchQueue.main.async { self.restartIfNeeded() }
                }
            }
            return true
        } catch {
            stop()
            return false
        }
    }

    private func handle(_ text: String) {
        guard running else { return }
        onHeard?(String(text.suffix(8)))
        let matches = text.compactMap { InkColor.match($0, among: colors) }
        guard matches.count > consumed else { return }
        let fresh = Array(matches[consumed...])
        consumed = matches.count
        for c in fresh { onColor?(c) }
    }

    private var restarts = 0

    func begin() -> Bool {
        restarts = 0
        return start()
    }

    private func restartIfNeeded() {
        guard running, restarts < 6 else { return }
        restarts += 1
        _ = start()
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
    }
}
