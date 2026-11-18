import AudioToolbox
import Foundation

/// 轻量音效：用系统内置声音，不额外打包音频文件
enum SFX {
    static var enabled = true

    static func tick() { play(1104) }
    static func tock() { play(1105) }
    static func correct() { play(1057) }
    static func wrong() { play(1053) }
    static func levelUp() { play(1025) }
    static func start() { play(1113) }

    private static func play(_ id: SystemSoundID) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(id)
    }
}
