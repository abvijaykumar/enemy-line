import Foundation

public enum MissionPhase: String, Codable, Sendable {
    case running, camp, extraction, victory, defeated
}

public enum MissionOperation: Int, CaseIterable, Codable, Sendable, Identifiable {
    case crashValley, convoyRoad, lastFlight
    public var id: Int { rawValue }
    public var title: String { ["Crash Valley", "Convoy Road", "Last Flight"][rawValue] }
    public var briefing: String {
        ["Your helicopter is down. Your squad is gone. Reach Ridge Camp, free a captured ally, and reach the radio beacon.",
         "Your rescued ally has marked a supply route. Break through an armored patrol, seize the depot, and reach extraction.",
         "Enemy helicopters guard the final corridor. Fight through the airfield camp and bring your growing team home."][rawValue]
    }
    public var campName: String { ["Ridge Camp", "Supply Depot", "Airfield Camp"][rawValue] }
    public var speed: Double { 8 + Double(rawValue) }
}

public enum Difficulty: String, CaseIterable, Codable, Sendable {
    case recruit, regular, veteran
    public var damage: Int { switch self { case .recruit: return 3; case .regular: return 5; case .veteran: return 8 } }
}

public enum ThreatKind: String, Codable, Sendable {
    case infantry, gunner, vehicle, helicopter, barrier, overhead
    public var obstacle: Bool { self == .barrier || self == .overhead }
}

public struct Threat: Identifiable, Equatable, Codable, Sendable {
    public let id: Int
    public let lane: Int
    public let distance: Double
    public var health: Int
    public let kind: ThreatKind
    public var obstacle: Bool { kind.obstacle }
    public var campDefender: Bool { (4...6).contains(id) }
}

/// Pure, serializable simulation. All combat and progression live here, not in the renderer.
public struct Mission: Codable, Sendable {
    public let operation: MissionOperation
    public let difficulty: Difficulty
    public private(set) var phase: MissionPhase = .running
    public private(set) var distance: Double = 0
    public private(set) var lane = 0
    public private(set) var health = 100
    public private(set) var ammo = 24
    public private(set) var reserve = 120
    public private(set) var grenades = 3
    public private(set) var recruited = false
    public private(set) var jumping = false
    public private(set) var sliding = false
    public private(set) var threats: [Threat]
    public private(set) var shots = 0
    public private(set) var hits = 0
    public private(set) var kills = 0
    public private(set) var elapsed: Double = 0
    public private(set) var grenadeSerial = 0
    public private(set) var damageSerial = 0
    public private(set) var aimLane = 0
    public var aimAssist = true
    public var paused = false
    private var shotCooldown: Double = 0
    private var enemyCooldown: Double = 1
    private var reloadRemaining: Double = 0
    private var jumpRemaining: Double = 0
    private var slideRemaining: Double = 0
    private var allyCooldown: Double = 0
    public var reloading: Bool { reloadRemaining > 0 }
    public var terminal: Bool { phase == .victory || phase == .defeated }
    public var campDefenders: Int { threats.filter { $0.campDefender && $0.health > 0 }.count }
    public var accuracy: Double { shots == 0 ? 0 : Double(hits) / Double(shots) }
    public var squadSize: Int { operation.rawValue + (recruited ? 1 : 0) }
    public var objective: String {
        switch phase {
        case .running: return "REACH \(operation.campName.uppercased())"
        case .camp: return "CLEAR \(operation.campName.uppercased())"
        case .extraction: return "REACH EXTRACTION"
        case .victory: return "MISSION COMPLETE"
        case .defeated: return "OFFICER DOWN"
        }
    }
    public var warning: String? {
        guard !terminal, !paused else { return nil }
        if let hazard = threats.first(where: { $0.obstacle && $0.health > 0 && $0.lane == lane && $0.distance > distance && $0.distance - distance < 16 }) {
            return hazard.kind == .barrier ? "LOW BARRIER · JUMP" : "OVERHEAD BEAM · SLIDE"
        }
        if threats.contains(where: { $0.kind == .helicopter && $0.health > 0 && $0.distance > distance && $0.distance - distance < 30 }) {
            return "AIR THREAT · ENGAGE OR TAKE COVER"
        }
        return nil
    }
    public var targetID: Int? {
        let visible = threats.filter { !$0.obstacle && $0.health > 0 && $0.distance >= distance && $0.distance - distance < 38 }
        return visible.filter { $0.lane == aimLane }.min(by: { $0.distance < $1.distance })?.id
            ?? (aimAssist ? visible.min(by: { $0.distance < $1.distance })?.id : nil)
    }

    public init(operation: MissionOperation = .crashValley, difficulty: Difficulty = .regular) {
        self.operation = operation
        self.difficulty = difficulty
        let extra = operation.rawValue
        threats = [
            Threat(id: 0, lane: -1, distance: 30, health: 1, kind: .barrier),
            Threat(id: 1, lane: 0, distance: 55, health: 3 + extra, kind: extra > 0 ? .vehicle : .infantry),
            Threat(id: 2, lane: 1, distance: 80, health: 1, kind: .overhead),
            Threat(id: 3, lane: -1, distance: 105, health: 3 + extra, kind: extra > 1 ? .helicopter : .infantry),
            Threat(id: 4, lane: -1, distance: 138, health: 5 + extra, kind: .infantry),
            Threat(id: 5, lane: 0, distance: 140, health: 6 + extra * 2, kind: extra > 0 ? .vehicle : .gunner),
            Threat(id: 6, lane: 1, distance: 142, health: 5 + extra * 2, kind: extra > 1 ? .helicopter : .infantry),
            Threat(id: 7, lane: 0, distance: 175, health: 3 + extra, kind: extra > 0 ? .vehicle : .infantry),
            Threat(id: 8, lane: 1, distance: 195, health: 1, kind: .barrier)
        ]
    }

    public mutating func move(_ direction: Int) {
        guard !paused, !terminal else { return }
        lane = min(1, max(-1, lane + direction))
        aimLane = lane
    }
    public mutating func aim(at lane: Int) { aimLane = min(1, max(-1, lane)) }
    public mutating func jump() {
        guard !paused, !terminal, !jumping, !sliding, phase != .camp else { return }
        jumpRemaining = 0.85; jumping = true
    }
    public mutating func slide() {
        guard !paused, !terminal, !jumping, !sliding, phase != .camp else { return }
        slideRemaining = 0.9; sliding = true
    }
    public mutating func reload() {
        guard !paused, !terminal, ammo < 24, reserve > 0, !reloading else { return }
        reloadRemaining = 1.4
    }
    public mutating func grenade() {
        guard !paused, !terminal, grenades > 0 else { return }
        grenades -= 1; grenadeSerial += 1
        for index in threats.indices {
            let t = threats[index]
            if !t.obstacle && t.health > 0 && t.distance >= distance && t.distance - distance < 40 {
                injure(index, amount: 5)
            }
        }
        updatePhase()
    }

    public mutating func tick(seconds: Double, firing: Bool) {
        guard !paused, !terminal, seconds.isFinite, seconds > 0 else { return }
        // Drop long background gaps, rather than advancing without player input.
        var remaining = min(seconds, 0.25)
        while remaining > 0 {
            let dt = min(remaining, 1.0 / 120)
            advance(dt, firing: firing)
            remaining -= dt
            if terminal { break }
        }
    }

    private mutating func injure(_ index: Int, amount: Int) {
        let wasAlive = threats[index].health > 0
        threats[index].health = max(0, threats[index].health - amount)
        if wasAlive && threats[index].health == 0 { kills += 1 }
    }
    private mutating func hurt(_ amount: Int) {
        health = max(0, health - amount)
        damageSerial += 1
    }
    private mutating func updatePhase() {
        if health == 0 { phase = .defeated; return }
        if phase == .camp && campDefenders == 0 {
            phase = .extraction
            recruited = true
            health = min(100, health + 30)
            reserve += 48
        }
        if phase == .extraction && distance >= 225 { distance = 225; phase = .victory }
    }
    private mutating func advance(_ dt: Double, firing: Bool) {
        elapsed += dt
        shotCooldown = max(0, shotCooldown - dt)
        enemyCooldown = max(0, enemyCooldown - dt)
        allyCooldown = max(0, allyCooldown - dt)
        jumpRemaining = max(0, jumpRemaining - dt)
        slideRemaining = max(0, slideRemaining - dt)
        jumping = jumpRemaining > 0; sliding = slideRemaining > 0
        if reloading {
            reloadRemaining = max(0, reloadRemaining - dt)
            if !reloading {
                let amount = min(24 - ammo, reserve)
                ammo += amount; reserve -= amount
            }
        }
        if phase == .running || phase == .extraction {
            let previous = distance
            distance += operation.speed * dt
            for index in threats.indices where threats[index].health > 0 {
                let t = threats[index]
                if t.distance > previous && t.distance <= distance {
                    let avoided = (t.kind == .barrier && jumping) || (t.kind == .overhead && sliding)
                    if t.lane == lane && !avoided { hurt(t.obstacle ? 20 : 10) }
                    // Passing a threat does not count as a kill.
                    threats[index].health = 0
                }
            }
            if phase == .running && distance >= 120 { distance = 120; phase = .camp }
        }
        if firing && shotCooldown == 0 && !reloading {
            if ammo == 0 { reload() }
            else {
                ammo -= 1; shots += 1; shotCooldown = 0.16
                if let id = targetID, let index = threats.firstIndex(where: { $0.id == id }) {
                    injure(index, amount: 1); hits += 1
                }
            }
        }
        if enemyCooldown == 0 {
            let nearby = threats.filter { !$0.obstacle && $0.health > 0 && $0.distance > distance && $0.distance - distance < 30 }
            if let attacker = nearby.first(where: { $0.lane == lane || $0.kind == .helicopter }) {
                if phase != .camp || firing {
                    hurt(difficulty.damage + operation.rawValue + (attacker.kind == .vehicle ? 2 : 0))
                }
                enemyCooldown = max(0.55, 1.2 - Double(operation.rawValue) * 0.15)
            }
        }
        if squadSize > 0 && allyCooldown == 0 {
            if let index = threats.indices.first(where: {
                let threat = threats[$0]
                return !threat.obstacle && threat.health > 0 && threat.distance > distance && threat.distance - distance < 30
            }) {
                injure(index, amount: 1)
                allyCooldown = max(0.3, 1.2 / Double(squadSize))
            }
        }
        updatePhase()
    }
}

public struct MissionRecord: Codable, Sendable {
    public let operation: MissionOperation
    public let seconds: Double
    public let accuracy: Double
    public let kills: Int
    public init(mission: Mission) {
        operation = mission.operation; seconds = mission.elapsed
        accuracy = mission.accuracy; kills = mission.kills
    }
}

public struct Campaign: Codable, Sendable {
    public var unlocked = 0
    public var records: [Int: MissionRecord] = [:]
    public var checkpoint: Mission?
    public var rallyPoint: Mission?
    public init() {}
    public mutating func complete(_ mission: Mission) {
        guard mission.phase == .victory else { return }
        unlocked = min(MissionOperation.allCases.count - 1, max(unlocked, mission.operation.rawValue + 1))
        if records[mission.operation.rawValue].map({ mission.elapsed < $0.seconds }) ?? true {
            records[mission.operation.rawValue] = MissionRecord(mission: mission)
        }
        checkpoint = nil; rallyPoint = nil
    }
}
