import SwiftUI
import LastLineCore
import GameController

struct GameSettings: Codable {
    var difficulty: Difficulty = .regular
    var aimAssist = true
    var autoFire = false
    var sound = true
    var haptics = true
    var reducedMotion = false
    var batterySaver = false
}

@MainActor
final class GameSession: ObservableObject {
    @Published var mission = Mission()
    @Published var playing = false
    @Published var firing = false
    @Published var campaign = Campaign()
    @Published var settings = GameSettings()
    @Published var notice: String?
    let renderer = Battlefield()
    let feedback = CombatFeedback()
    private let defaults: UserDefaults
    private var saveTime: Double = 0
    private var controllerObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var connectedControllers: [GCController] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "enemy-line.campaign.v1") {
            do { campaign = try JSONDecoder().decode(Campaign.self, from: data) }
            catch { notice = "Saved progress could not be read. A new campaign is available; the old save has been retained until your next save." }
        }
        if let data = defaults.data(forKey: "enemy-line.settings.v1") {
            settings = (try? JSONDecoder().decode(GameSettings.self, from: data)) ?? GameSettings()
        }
        configureControllers()
        controllerObserver = NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.configureControllers() }
        }
        disconnectObserver = NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.firing = false
                self?.configureControllers()
            }
        }
    }

    func start(_ operation: MissionOperation) {
        guard operation.rawValue <= campaign.unlocked else { return }
        mission = Mission(operation: operation, difficulty: settings.difficulty)
        mission.aimAssist = settings.aimAssist
        campaign.rallyPoint = mission
        campaign.checkpoint = mission
        playing = true; firing = false; saveTime = 0
        save()
        renderer.reset(mission)
    }

    func resume() {
        guard var saved = campaign.checkpoint, !saved.terminal else { return }
        saved.paused = false
        saved.aimAssist = settings.aimAssist
        mission = saved; playing = true; firing = false
        renderer.reset(mission)
    }

    func retryCheckpoint() {
        guard var point = campaign.rallyPoint else { start(mission.operation); return }
        point.paused = false; point.aimAssist = settings.aimAssist
        mission = point; playing = true; firing = false
        campaign.checkpoint = point
        save(); renderer.reset(mission)
    }

    func tick(_ seconds: Double) {
        guard playing, !mission.paused, !mission.terminal else { return }
        let previous = mission
        mission.aimAssist = settings.aimAssist
        mission.tick(seconds: seconds, firing: firing || (settings.autoFire && mission.targetID != nil))
        if mission.phase != previous.phase {
            if mission.phase == .camp || mission.phase == .extraction {
                campaign.rallyPoint = mission
                checkpoint()
            }
            if mission.phase == .victory { campaign.complete(mission); save() }
            if mission.phase == .defeated {
                campaign.checkpoint = campaign.rallyPoint
                save()
            }
            if mission.phase == .victory || mission.phase == .extraction { feedback.play(.success, settings: settings) }
        }
        if mission.shots > previous.shots { feedback.play(.shot, settings: settings) }
        if mission.damageSerial > previous.damageSerial { feedback.play(.damage, settings: settings) }
        renderer.update(mission, previous: previous, dt: seconds, reducedMotion: settings.reducedMotion, firing: firing || (settings.autoFire && mission.targetID != nil))
        saveTime += seconds
        if saveTime >= 3 { checkpoint(); saveTime = 0 }
        if mission.terminal { firing = false }
    }

    func grenade() {
        guard playing else { return }
        let previous = mission
        mission.grenade()
        if previous.grenades != mission.grenades {
            feedback.play(.explosion, settings: settings)
            renderer.explode()
        }
        // Completion and checkpoint handling occur on the next frame.
        if previous.phase != mission.phase && mission.phase == .extraction {
            campaign.rallyPoint = mission; checkpoint()
            feedback.play(.success, settings: settings)
        }
    }

    func pause() {
        guard playing, !mission.terminal else { return }
        mission.paused = true; firing = false; checkpoint()
    }
    func unpause() { mission.paused = false; firing = false }
    func leave() { if !mission.terminal { checkpoint() }; firing = false; playing = false }
    func checkpoint() {
        guard !mission.terminal else { return }
        campaign.checkpoint = mission; save()
    }
    func save() {
        do {
            defaults.set(try JSONEncoder().encode(campaign), forKey: "enemy-line.campaign.v1")
            defaults.set(try JSONEncoder().encode(settings), forKey: "enemy-line.settings.v1")
        } catch { notice = "Progress could not be saved: \(error.localizedDescription)" }
    }
    func resetCampaign() { campaign = Campaign(); save() }

    private func configureControllers() {
        connectedControllers = GCController.controllers()
        for controller in connectedControllers {
            guard let pad = controller.extendedGamepad else { continue }
            pad.dpad.left.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in if self?.playing == true { self?.mission.move(-1) } } }
            }
            pad.dpad.right.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in if self?.playing == true { self?.mission.move(1) } } }
            }
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in if self?.playing == true { self?.mission.jump() } } }
            }
            pad.buttonB.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in if self?.playing == true { self?.mission.slide() } } }
            }
            pad.buttonX.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in if self?.playing == true { self?.mission.reload() } } }
            }
            pad.rightTrigger.pressedChangedHandler = { [weak self] _, _, down in
                Task { @MainActor in if self?.playing == true { self?.firing = down } }
            }
            pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in self?.grenade() } }
            }
            pad.buttonMenu.pressedChangedHandler = { [weak self] _, _, down in
                if down { Task { @MainActor in
                    guard let self, self.playing else { return }
                    if self.mission.paused { self.unpause() } else { self.pause() }
                } }
            }
        }
    }
}
