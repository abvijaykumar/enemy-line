import Foundation
import XCTest
@testable import LastLineCore

final class MissionTests: XCTestCase {
    func testLaneBoundsAndPause() {
        var mission = Mission()
        for _ in 0..<10 { mission.move(1) }
        XCTAssertEqual(mission.lane, 1)
        mission.paused = true
        mission.move(-1)
        mission.tick(seconds: 0.1, firing: true)
        XCTAssertEqual(mission.lane, 1)
        XCTAssertEqual(mission.distance, 0)
        XCTAssertEqual(mission.ammo, 24)
    }

    func testMissionCanBeCompletedWithRecruit() {
        var mission = Mission()
        // Clear each camp lane in cover combat, then proceed to extraction.
        for _ in 0..<30000 {
            if mission.phase == .camp {
                if let threat = mission.threats.first(where: { (4...6).contains($0.id) && $0.health > 0 }) {
                    mission.move(threat.lane - mission.lane)
                }
            }
            mission.tick(seconds: 1.0 / 60, firing: true)
            if mission.terminal { break }
        }
        XCTAssertEqual(mission.phase, .victory)
        XCTAssertTrue(mission.recruited)
        XCTAssertGreaterThan(mission.health, 0)
    }

    func testReloadTransfersAmmunitionWithoutCreatingIt() {
        var mission = Mission()
        mission.tick(seconds: 0.02, firing: true)
        XCTAssertEqual(mission.ammo, 23)
        mission.reload()
        for _ in 0..<120 { mission.tick(seconds: 1.0 / 60, firing: false) }
        XCTAssertEqual(mission.ammo, 24)
        XCTAssertEqual(mission.reserve, 119)
    }

    func testFrameRatesProduceEquivalentTravel() {
        var fast = Mission()
        var slow = Mission()
        for _ in 0..<600 { fast.tick(seconds: 1.0 / 60, firing: false) }
        for _ in 0..<300 { slow.tick(seconds: 1.0 / 30, firing: false) }
        XCTAssertEqual(fast.distance, slow.distance, accuracy: 0.001)
        XCTAssertEqual(fast.health, slow.health)
    }
}

final class CampaignTests: XCTestCase {
    private func play(_ operation: MissionOperation, difficulty: Difficulty = .regular) -> Mission {
        var mission = Mission(operation: operation, difficulty: difficulty)
        for _ in 0..<15000 {
            if mission.phase == .camp, let t = mission.threats.first(where: { $0.campDefender && $0.health > 0 }) {
                mission.move(t.lane - mission.lane)
            }
            mission.tick(seconds: 1.0 / 60, firing: mission.targetID != nil)
            if mission.terminal { break }
        }
        return mission
    }

    func testEveryOperationCompletesOnEveryDifficulty() {
        for operation in MissionOperation.allCases {
            for difficulty in Difficulty.allCases {
                let mission = play(operation, difficulty: difficulty)
                XCTAssertEqual(mission.phase, .victory, "\(operation) / \(difficulty)")
                XCTAssertTrue(mission.recruited)
            }
        }
    }

    func testCampaignOnlyUnlocksAfterVictory() {
        var campaign = Campaign()
        campaign.complete(Mission())
        XCTAssertEqual(campaign.unlocked, 0)
        let victory = play(.crashValley)
        campaign.complete(victory)
        XCTAssertEqual(campaign.unlocked, 1)
        XCTAssertNotNil(campaign.records[0])
        campaign.complete(play(.convoyRoad))
        XCTAssertEqual(campaign.unlocked, 2)
        campaign.complete(play(.lastFlight))
        XCTAssertEqual(campaign.unlocked, 2)
    }

    func testSaveRoundTripContinuesIdentically() throws {
        var original = Mission(operation: .lastFlight)
        for _ in 0..<300 { original.tick(seconds: 1.0 / 60, firing: true) }
        original.reload()
        var restored = try JSONDecoder().decode(Mission.self, from: JSONEncoder().encode(original))
        for _ in 0..<600 {
            original.tick(seconds: 1.0 / 60, firing: true)
            restored.tick(seconds: 1.0 / 60, firing: true)
        }
        XCTAssertEqual(original.distance, restored.distance)
        XCTAssertEqual(original.ammo, restored.ammo)
        XCTAssertEqual(original.health, restored.health)
        XCTAssertEqual(original.threats, restored.threats)
    }

    func testCoverProtectsAndGrenadesClearCamp() {
        var mission = Mission()
        for _ in 0..<1000 {
            mission.tick(seconds: 0.02, firing: false)
            if mission.phase == .camp { break }
        }
        XCTAssertEqual(mission.phase, .camp)
        let health = mission.health
        for _ in 0..<300 { mission.tick(seconds: 0.02, firing: false) }
        XCTAssertEqual(mission.health, health)
        mission.grenade()
        mission.grenade()
        XCTAssertEqual(mission.phase, .extraction)
        XCTAssertTrue(mission.recruited)
        XCTAssertEqual(mission.grenades, 1)
    }

    func testGrenadesCannotBeThrownWhilePausedOrBelowZero() {
        var mission = Mission()
        mission.paused = true
        mission.grenade()
        XCTAssertEqual(mission.grenades, 3)
        mission.paused = false
        for _ in 0..<10 { mission.grenade() }
        XCTAssertEqual(mission.grenades, 0)
        XCTAssertEqual(mission.grenadeSerial, 3)
    }

    func testJumpAndSlideAvoidTheirRespectiveObstacles() {
        var jumping = Mission()
        jumping.move(-1)
        for _ in 0..<220 { jumping.tick(seconds: 1.0 / 60, firing: false) }
        jumping.jump()
        for _ in 0..<20 { jumping.tick(seconds: 1.0 / 60, firing: false) }
        XCTAssertEqual(jumping.health, 100)
        var sliding = Mission()
        sliding.move(1)
        for _ in 0..<580 { sliding.tick(seconds: 1.0 / 60, firing: false) }
        sliding.slide()
        for _ in 0..<30 { sliding.tick(seconds: 1.0 / 60, firing: false) }
        XCTAssertEqual(sliding.health, 100)
    }

    func testNoSimulationAdvanceForInvalidOrPausedTime() {
        var mission = Mission()
        mission.tick(seconds: .nan, firing: true)
        mission.tick(seconds: .infinity, firing: true)
        mission.tick(seconds: -1, firing: true)
        mission.paused = true
        mission.tick(seconds: 1000, firing: true)
        XCTAssertEqual(mission.distance, 0)
        XCTAssertEqual(mission.shots, 0)
    }

    func testCampCannotBeSkippedByRunning() {
        var mission = Mission()
        for _ in 0..<2000 { mission.tick(seconds: 0.02, firing: false) }
        XCTAssertEqual(mission.phase, .camp)
        XCTAssertEqual(mission.distance, 120)
        XCTAssertFalse(mission.recruited)
    }
}
