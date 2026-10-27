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
