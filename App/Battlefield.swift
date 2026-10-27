import SwiftUI
import RealityKit
import LastLineCore
import simd

/// Procedural, self-contained art. External production assets can replace each factory.
@MainActor
final class Battlefield {
    let root = Entity()
    private let scenery = Entity()
    private let camera = PerspectiveCamera()
    private let player = Entity()
    private let allies = Entity()
    private var enemies: [Int: Entity] = [:]
    private var rotors: [Entity] = []
    private var legs: [Entity] = []
    private var built = false
    private var clock: Float = 0
    private var shotLife: Double = 0
    private var explosionLife: Double = 0
    private let flash = ModelEntity(mesh: .generateSphere(radius: 0.14), materials: [UnlitMaterial(color: .yellow)])
    private let explosion = ModelEntity(mesh: .generateSphere(radius: 1), materials: [UnlitMaterial(color: .orange)])
    private let tracer = ModelEntity(mesh: .generateCylinder(height: 1, radius: 0.018), materials: [UnlitMaterial(color: .yellow)])

    private func material(_ color: SIMD3<Float>, metal: Bool = false) -> SimpleMaterial {
        SimpleMaterial(color: .init(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1), roughness: metal ? 0.45 : 0.9, isMetallic: metal)
    }
    private func box(_ size: SIMD3<Float>, _ color: SIMD3<Float>, _ position: SIMD3<Float>, parent: Entity) -> ModelEntity {
        let item = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.04), materials: [material(color)])
        item.position = position; parent.addChild(item); return item
    }
    private func sphere(_ radius: Float, _ color: SIMD3<Float>, _ position: SIMD3<Float>, parent: Entity) -> ModelEntity {
        let item = ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])
        item.position = position; parent.addChild(item); return item
    }
    private func cylinder(_ height: Float, _ radius: Float, _ color: SIMD3<Float>, _ position: SIMD3<Float>, parent: Entity) -> ModelEntity {
        let item = ModelEntity(mesh: .generateCylinder(height: height, radius: radius), materials: [material(color)])
        item.position = position; parent.addChild(item); return item
    }

    private func soldier(friendly: Bool, animate: Bool = false) -> Entity {
        let unit = Entity()
        let cloth: SIMD3<Float> = friendly ? [0.24, 0.31, 0.17] : [0.43, 0.28, 0.19]
        let vest: SIMD3<Float> = friendly ? [0.16, 0.22, 0.12] : [0.25, 0.19, 0.14]
        let torso = box([0.6, 0.75, 0.32], cloth, [0, 1.18, 0], parent: unit)
        torso.orientation = simd_quatf(angle: -0.08, axis: [1, 0, 0])
        box([0.64, 0.46, 0.36], vest, [0, 1.22, -0.02], parent: unit)
        box([0.47, 0.53, 0.22], vest, [0, 1.25, 0.27], parent: unit)
        for x: Float in [-0.2, 0, 0.2] {
            box([0.15, 0.2, 0.12], cloth, [x, 1.03, -0.25], parent: unit)
        }
        sphere(0.2, [0.54, 0.4, 0.28], [0, 1.78, 0], parent: unit)
        let helmet = sphere(0.24, vest, [0, 1.88, 0], parent: unit)
        helmet.scale.y = 0.7
        box([0.37, 0.1, 0.12], [0.08, 0.1, 0.09], [0, 1.8, -0.18], parent: unit)
        for x: Float in [-0.19, 0.19] {
            let pivot = Entity(); pivot.position = [x, 0.86, 0]; unit.addChild(pivot)
            cylinder(0.66, 0.12, cloth, [0, -0.33, 0], parent: pivot)
            box([0.25, 0.22, 0.38], [0.1, 0.11, 0.08], [0, -0.75, -0.04], parent: pivot)
            if animate { legs.append(pivot) }
        }
        for x: Float in [-0.39, 0.39] {
            let arm = cylinder(0.57, 0.1, cloth, [x, 1.18, -0.2], parent: unit)
            arm.orientation = simd_quatf(angle: -0.8, axis: [1, 0, 0])
        }
        box([0.13, 0.16, 0.77], [0.08, 0.09, 0.08], [0.28, 1.21, -0.53], parent: unit)
        cylinder(0.35, 0.035, [0.1, 0.11, 0.1], [0.28, 1.21, -1], parent: unit)
            .orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        return unit
    }

    private func vehicle() -> Entity {
        let car = Entity()
        box([1.8, 0.7, 3.1], [0.23, 0.29, 0.16], [0, 0.85, 0], parent: car)
        box([1.55, 0.65, 1.45], [0.2, 0.25, 0.14], [0, 1.48, -0.2], parent: car)
        box([1.3, 0.4, 0.06], [0.14, 0.23, 0.25], [0, 1.5, -0.96], parent: car)
        for x: Float in [-0.95, 0.95] { for z: Float in [-1, 1] {
            let wheel = cylinder(0.32, 0.43, [0.07, 0.07, 0.065], [x, 0.5, z], parent: car)
            wheel.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        } }
        box([0.4, 0.3, 0.5], [0.11, 0.13, 0.09], [0, 1.95, 0.1], parent: car)
        box([0.1, 0.1, 1.1], [0.08, 0.08, 0.07], [0, 1.98, -0.6], parent: car)
        return car
    }

    private func helicopter(wreck: Bool = false) -> Entity {
        let craft = Entity()
        let hull = sphere(1, [0.22, 0.27, 0.18], [0, 0, 0], parent: craft)
        hull.scale = [0.85, 0.8, 1.8]
        let glass = sphere(0.75, [0.12, 0.21, 0.24], [0, 0.12, -1.1], parent: craft)
        glass.scale = [0.9, 0.7, 0.9]
        box([0.3, 0.35, 3.6], [0.2, 0.24, 0.16], [0, 0.15, 2.2], parent: craft)
        box([2.2, 0.1, 0.45], [0.18, 0.21, 0.14], [0, 0.3, 3.8], parent: craft)
        let rotor = Entity(); rotor.position.y = 1.15; craft.addChild(rotor)
        box([6, 0.06, 0.18], [0.08, 0.09, 0.07], .zero, parent: rotor)
        box([0.18, 0.06, 6], [0.08, 0.09, 0.07], .zero, parent: rotor)
        if !wreck { rotors.append(rotor) }
        for x: Float in [-0.8, 0.8] { box([0.1, 0.12, 2.8], [0.1, 0.11, 0.09], [x, -0.9, 0], parent: craft) }
        return craft
    }

    func build() {
        guard !built else { return }; built = true
        root.addChild(scenery)
        camera.camera.fieldOfViewInDegrees = 62
        camera.look(at: [0, 1.5, -14], from: [0, 3.6, 6], relativeTo: nil)
        root.addChild(camera)
        let sun = DirectionalLight(); sun.light.intensity = 4500
        sun.light.color = .init(red: 1, green: 0.85, blue: 0.65, alpha: 1)
        sun.shadow = .init(maximumDistance: 65, depthBias: 2)
        sun.look(at: [0, 0, -40], from: [-30, 50, 10], relativeTo: nil)
        root.addChild(sun)
        let fill = DirectionalLight(); fill.light.intensity = 1300
        fill.look(at: [0, 0, -20], from: [10, 20, -80], relativeTo: nil); root.addChild(fill)
        box([200, 0.2, 600], [0.19, 0.26, 0.14], [0, -0.25, -200], parent: scenery)
        box([8.5, 0.16, 500], [0.39, 0.32, 0.22], [0, -0.1, -200], parent: scenery)
        for i in 0..<90 {
            let side: Float = i % 2 == 0 ? -1 : 1
            let z = -Float(i / 2) * 6 + 10
            let x = side * (6 + Float((i * 7) % 12))
            let tree = Entity(); tree.position = [x, 0, z]; scenery.addChild(tree)
            cylinder(5, 0.22, [0.22, 0.19, 0.12], [0, 2.5, 0], parent: tree)
            let crown = sphere(2, [0.14 + Float(i % 3) * 0.025, 0.26, 0.1], [0, 5.4, 0], parent: tree)
            crown.scale = [1.1, 0.65, 1]
            let rock = sphere(0.5 + Float(i % 3) * 0.15, [0.34, 0.35, 0.28], [side * 4.6, 0.25, z - 2], parent: scenery)
            rock.scale.y = 0.6
        }
        for i in 0..<16 {
            let hill = sphere(15, [0.2, 0.29, 0.22], [i % 2 == 0 ? -38 : 38, 0, -Float(i / 2) * 45], parent: scenery)
            hill.scale = [1.5, Float(1 + i % 3), 1.6]
        }
        buildCamp()
        let wreck = helicopter(wreck: true); wreck.position = [-7, 1, -8]
        wreck.orientation = simd_quatf(angle: 0.45, axis: [0, 0, 1]); scenery.addChild(wreck)
        let body = soldier(friendly: true, animate: true); player.addChild(body); root.addChild(player)
        for i in 0..<3 {
            let ally = soldier(friendly: true); ally.position = [Float(i - 1) * 1.5, 0, 2 + Float(i % 2)]
            allies.addChild(ally)
        }
        root.addChild(allies)
        root.addChild(flash); root.addChild(tracer); root.addChild(explosion)
        flash.isEnabled = false; tracer.isEnabled = false; explosion.isEnabled = false
    }

    private func buildCamp() {
        for x: Float in [-9, 9] {
            box([5, 3, 6], [0.35, 0.31, 0.21], [x, 1.5, -140], parent: scenery)
            let roof = box([6, 0.25, 7], [0.23, 0.25, 0.19], [x, 3.2, -140], parent: scenery)
            roof.orientation = simd_quatf(angle: x < 0 ? 0.08 : -0.08, axis: [0, 0, 1])
            box([1.1, 2.2, 0.1], [0.1, 0.12, 0.08], [x, 1.1, -136.95], parent: scenery)
        }
        for x: Float in [-1.9, -0.63, 0.63, 1.9] {
            for row in 0..<3 {
                box([1.2, 0.27, 0.65], [0.48, 0.42, 0.27], [x, Float(row) * 0.27 + 0.14, -122], parent: scenery)
            }
        }
        for x: Float in [-2.4, 0, 2.4] {
            box([1.5, 0.9, 0.7], [0.44, 0.4, 0.27], [x, 0.45, -143], parent: scenery)
        }
        for x: Float in [7, 10] { for z: Float in [-130, -133] {
            box([0.2, 7, 0.2], [0.29, 0.25, 0.17], [x, 3.5, z], parent: scenery)
        } }
        box([3.7, 0.25, 3.7], [0.31, 0.27, 0.18], [8.5, 6, -131.5], parent: scenery)
        box([4.3, 0.3, 4.3], [0.22, 0.25, 0.17], [8.5, 8, -131.5], parent: scenery)
        for x: Float in [-4.5, 4.5] {
            box([0.2, 4, 0.2], [0.38, 0.36, 0.26], [x, 2, -225], parent: scenery)
        }
        box([9, 0.5, 0.3], [0.23, 0.35, 0.18], [0, 4, -225], parent: scenery)
        let beacon = ModelEntity(mesh: .generateSphere(radius: 0.4), materials: [UnlitMaterial(color: .green)])
        beacon.position = [0, 4.6, -225]; scenery.addChild(beacon)
    }

    func reset(_ mission: Mission) {
        build()
        for item in enemies.values { item.removeFromParent() }
        enemies.removeAll()
        rotors.removeAll()
        for t in mission.threats {
            let entity: Entity
            switch t.kind {
            case .vehicle: entity = vehicle()
            case .helicopter: entity = helicopter()
            case .infantry, .gunner:
                entity = soldier(friendly: false)
                entity.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
                if t.kind == .gunner { box([1.5, 0.7, 0.6], [0.4, 0.37, 0.25], [0, 0.35, -0.5], parent: entity) }
            case .barrier:
                entity = Entity(); box([1.8, 0.65, 0.7], [0.4, 0.3, 0.17], [0, 0.32, 0], parent: entity)
            case .overhead:
                entity = Entity()
                for x: Float in [-0.9, 0.9] { box([0.15, 2.3, 0.2], [0.4, 0.32, 0.18], [x, 1.15, 0], parent: entity) }
                box([2, 0.6, 0.35], [0.45, 0.33, 0.16], [0, 1.65, 0], parent: entity)
            }
            if !t.obstacle {
                let marker = ModelEntity(mesh: .generateSphere(radius: 0.11), materials: [UnlitMaterial(color: .red)])
                marker.name = "target-marker"
                marker.position = [0, t.kind == .helicopter ? 1.7 : 2.4, 0]; entity.addChild(marker)
            }
            root.addChild(entity); enemies[t.id] = entity
        }
        clock = 0; shotLife = 0; explosionLife = 0
        player.position = [Float(mission.lane) * 2.4, 0, 0]
        update(mission, previous: mission, dt: 0, reducedMotion: true)
    }

    func explode() { explosionLife = 0.45; explosion.position = [0, 1, -18] }

    func update(_ mission: Mission, previous: Mission, dt: Double, reducedMotion: Bool, firing: Bool = false) {
        let delta = Float(min(dt, 0.1)); clock += delta
        scenery.position.z = Float(mission.distance)
        let desired = SIMD3<Float>(Float(mission.lane) * 2.4, mission.jumping ? 1.1 : 0, 0)
        player.position += (desired - player.position) * min(1, delta * 16 + (dt == 0 ? 1 : 0))
        player.scale.y = mission.sliding || (mission.phase == .camp && !firing) ? 0.65 : 1
        for (i, leg) in legs.enumerated() {
            let angle: Float = mission.phase == .camp || reducedMotion ? 0 : sin(clock * 12 + Float(i) * .pi) * 0.45
            leg.orientation = simd_quatf(angle: angle, axis: [1, 0, 0])
        }
        let cameraX = player.position.x * 0.25
        camera.look(at: [cameraX, 1.5, -14], from: [cameraX, 3.6, 6], relativeTo: nil)
        for t in mission.threats {
            guard let model = enemies[t.id] else { continue }
            let ahead = Float(t.distance - mission.distance)
            model.isEnabled = t.health > 0 && ahead > -5 && ahead < 85
            if let marker = model.findEntity(named: "target-marker") as? ModelEntity {
                marker.model?.materials = [UnlitMaterial(color: mission.targetID == t.id ? .yellow : .red)]
            }
            model.position = [Float(t.lane) * 2.4, t.kind == .helicopter ? 6 + (reducedMotion ? 0 : sin(clock * 2) * 0.4) : 0, -ahead]
        }
        for rotor in rotors { rotor.orientation = simd_quatf(angle: clock * (reducedMotion ? 3 : 30), axis: [0, 1, 0]) }
        for (i, ally) in allies.children.enumerated() { ally.isEnabled = i < mission.squadSize }
        if mission.shots > previous.shots {
            shotLife = 0.07
            let start = player.position + SIMD3<Float>(0.28, 1.2, -1)
            flash.position = start
            let target = mission.targetID.flatMap { enemies[$0]?.position } ?? SIMD3<Float>(Float(mission.aimLane) * 2.4, 1.2, -30)
            let end = target + SIMD3<Float>(0, 1, 0)
            let vector = end - start
            tracer.position = (start + end) / 2
            tracer.scale = [1, simd_length(vector), 1]
            tracer.orientation = simd_quatf(from: [0, 1, 0], to: simd_normalize(vector))
        }
        shotLife = max(0, shotLife - dt)
        flash.isEnabled = shotLife > 0; tracer.isEnabled = shotLife > 0
        explosionLife = max(0, explosionLife - dt)
        explosion.isEnabled = explosionLife > 0
        explosion.scale = SIMD3<Float>(repeating: Float((0.45 - explosionLife) * 8 + 0.2))
    }
}
