import Foundation

public enum MissionPhase: String, Codable, Sendable {
    case running, camp, extraction, victory, defeated
}

public struct Threat: Identifiable, Equatable, Sendable {
    public let id: Int
    public let lane: Int
    public let distance: Double
    public var health: Int
    public let obstacle: Bool
}

/// Deterministic simulation, independent of rendering and frame rate.
public struct Mission: Sendable {
    public private(set) var phase: MissionPhase = .running
    public private(set) var distance: Double = 0
    public private(set) var lane = 0
    public private(set) var health = 100
    public private(set) var ammo = 24
    public private(set) var reserve = 120
    public private(set) var recruited = false
    public private(set) var jumping = false
    public private(set) var threats: [Threat]
    public private(set) var shots = 0
    public private(set) var hits = 0
    public var paused = false
    private var shotCooldown: Double = 0
    private var enemyCooldown: Double = 0
    private var reloadRemaining: Double = 0
    private var jumpRemaining: Double = 0
    private var allyCooldown: Double = 0
    public var reloading: Bool { reloadRemaining > 0 }
    public var terminal: Bool { phase == .victory || phase == .defeated }
    public var objective: String {
        switch phase {
        case .running: return "REACH RIDGE CAMP"
        case .camp: return "CLEAR THE CAMP"
        case .extraction: return "REACH EXTRACTION"
        case .victory: return "MISSION COMPLETE"
        case .defeated: return "OFFICER DOWN"
        }
    }

    public init() {
        threats = [
            Threat(id: 0, lane: -1, distance: 30, health: 1, obstacle: true),
            Threat(id: 1, lane: 0, distance: 55, health: 2, obstacle: false),
            Threat(id: 2, lane: 1, distance: 80, health: 1, obstacle: true),
            Threat(id: 3, lane: -1, distance: 105, health: 2, obstacle: false),
            Threat(id: 4, lane: -1, distance: 138, health: 4, obstacle: false),
            Threat(id: 5, lane: 0, distance: 140, health: 4, obstacle: false),
            Threat(id: 6, lane: 1, distance: 142, health: 4, obstacle: false),
            Threat(id: 7, lane: 0, distance: 175, health: 2, obstacle: false),
            Threat(id: 8, lane: 1, distance: 195, health: 1, obstacle: true)
        ]
    }

    public mutating func move(_ direction: Int) {
        guard !paused, !terminal else { return }
        lane = min(1, max(-1, lane + direction))
    }

    public mutating func jump() {
        guard !paused, !terminal, !jumping, phase != .camp else { return }
        jumpRemaining = 0.85
        jumping = true
    }

    public mutating func reload() {
        guard !paused, !terminal, ammo < 24, reserve > 0, !reloading else { return }
        reloadRemaining = 1.4
    }

    public mutating func tick(seconds: Double, firing: Bool) {
        guard !paused, !terminal, seconds.isFinite, seconds > 0 else { return }
        // Substeps keep collision and weapon timing stable after a slow frame.
        var remaining = min(seconds, 0.25)
        while remaining > 0 {
            let dt = min(remaining, 1.0 / 120)
            advance(dt, firing: firing)
            remaining -= dt
            if terminal { break }
        }
    }

    private mutating func advance(_ dt: Double, firing: Bool) {
        shotCooldown = max(0, shotCooldown - dt)
        enemyCooldown = max(0, enemyCooldown - dt)
        allyCooldown = max(0, allyCooldown - dt)
        jumpRemaining = max(0, jumpRemaining - dt)
        jumping = jumpRemaining > 0
        if reloading {
            reloadRemaining = max(0, reloadRemaining - dt)
            if !reloading {
                let amount = min(24 - ammo, reserve)
                ammo += amount
                reserve -= amount
            }
        }
        if phase == .running || phase == .extraction {
            let previous = distance
            distance += 8 * dt
            for index in threats.indices where threats[index].health > 0 {
                let threat = threats[index]
                if threat.distance > previous && threat.distance <= distance {
                    if threat.lane == lane && !(threat.obstacle && jumping) {
                        health = max(0, health - (threat.obstacle ? 20 : 10))
                    }
                    threats[index].health = 0
                }
            }
            if phase == .running && distance >= 120 {
                distance = 120
                phase = .camp
            }
        }
        if firing && shotCooldown == 0 && !reloading {
            if ammo == 0 { reload() }
            else {
                ammo -= 1
                shots += 1
                shotCooldown = 0.16
                if let index = threats.indices.first(where: {
                    let t = threats[$0]
                    return !t.obstacle && t.health > 0 && t.lane == lane
                        && t.distance >= distance && t.distance - distance < 35
                }) {
                    threats[index].health -= 1
                    hits += 1
                }
            }
        }
        if enemyCooldown == 0 && threats.contains(where: {
            !$0.obstacle && $0.health > 0 && $0.lane == lane
                && $0.distance > distance && $0.distance - distance < 28
        }) {
            // In camp, releasing fire returns the officer to cover.
            if phase != .camp || firing { health = max(0, health - 5) }
            enemyCooldown = 1.2
        }
        if phase == .camp && !threats.contains(where: { (4...6).contains($0.id) && $0.health > 0 }) {
            phase = .extraction
            recruited = true
            health = min(100, health + 30)
            reserve += 48
        }
        if recruited && allyCooldown == 0 {
            if let index = threats.indices.first(where: {
                !$0.obstacle && $0.health > 0 && $0.distance > distance && $0.distance - distance < 30
            }) {
                threats[index].health -= 1
                allyCooldown = 0.8
            }
        }
        if health == 0 { phase = .defeated }
        else if phase == .extraction && distance >= 225 { phase = .victory }
    }
}
