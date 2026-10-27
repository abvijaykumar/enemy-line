import AVFoundation
#if os(iOS)
import UIKit
#endif

@MainActor
final class CombatFeedback {
    enum Event: String { case shot, damage, explosion, success }
    private var players: [String: AVAudioPlayer] = [:]
    private var configured = false

    func play(_ event: Event, settings: GameSettings) {
        #if os(iOS)
        if !configured {
            // Respect silent mode and coexist with music from other apps.
            try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            configured = true
        }
        if settings.haptics {
            if event == .success { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            else if event == .damage { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
            else { UIImpactFeedbackGenerator(style: event == .shot ? .light : .heavy).impactOccurred() }
        }
        #endif
        guard settings.sound else { return }
        if players[event.rawValue] == nil,
           let url = Bundle.main.url(forResource: event.rawValue, withExtension: "wav"),
           let player = try? AVAudioPlayer(contentsOf: url) {
            player.volume = event == .shot ? 0.25 : 0.5
            player.prepareToPlay()
            players[event.rawValue] = player
        }
        players[event.rawValue]?.currentTime = 0
        players[event.rawValue]?.play()
    }
}
