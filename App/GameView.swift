import SwiftUI
import RealityKit
import LastLineCore

@MainActor
final class GameSession: ObservableObject {
    @Published var mission = Mission()
    @Published var started = false
    var firing = false
    let world = Entity()
    let officer = Entity()
    private var threatModels: [Int: Entity] = [:]
    private var built = false

    private func box(_ size: SIMD3<Float>, color: SIMD3<Float>, at position: SIMD3<Float>) -> ModelEntity {
        let material = SimpleMaterial(color: .init(red: CGFloat(color.x), green: CGFloat(color.y), blue: CGFloat(color.z), alpha: 1), roughness: 0.85, isMetallic: false)
        let entity = ModelEntity(mesh: .generateBox(size: size), materials: [material])
        entity.position = position
        return entity
    }

    func build() {
        guard !built else { return }
        built = true
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 65
        camera.look(at: [0, 1.3, -14], from: [0, 4.8, 8], relativeTo: nil)
        world.addChild(camera)
        let sun = DirectionalLight()
        sun.light.intensity = 3000
        sun.look(at: [0, 0, -20], from: [10, 20, 10], relativeTo: nil)
        world.addChild(sun)
        world.addChild(box([100, 0.2, 600], color: [0.16, 0.24, 0.18], at: [0, -0.3, -200]))
        world.addChild(box([8, 0.15, 500], color: [0.36, 0.31, 0.23], at: [0, -0.1, -200]))
        // Recognizable blockout silhouette; production character assets come later.
        officer.addChild(box([0.7, 1.1, 0.45], color: [0.22, 0.29, 0.19], at: [0, 1.1, 0]))
        officer.addChild(box([0.45, 0.45, 0.45], color: [0.3, 0.34, 0.22], at: [0, 1.9, 0]))
        officer.addChild(box([0.18, 0.22, 0.95], color: [0.12, 0.13, 0.12], at: [0.5, 1.2, -0.5]))
        for x: Float in [-0.22, 0.22] {
            officer.addChild(box([0.24, 0.65, 0.3], color: [0.19, 0.23, 0.16], at: [x, 0.3, 0]))
        }
        world.addChild(officer)
        for threat in mission.threats {
            let model = box(threat.obstacle ? [1.8, 0.7, 0.9] : [0.7, 1.8, 0.6],
                            color: threat.obstacle ? [0.38, 0.29, 0.18] : [0.64, 0.23, 0.17],
                            at: .zero)
            threatModels[threat.id] = model
            world.addChild(model)
        }
        render()
    }

    func render() {
        officer.position = [Float(mission.lane) * 2.4, mission.jumping ? 1 : 0, 0]
        for threat in mission.threats {
            guard let model = threatModels[threat.id] else { continue }
            let ahead = Float(threat.distance - mission.distance)
            model.isEnabled = threat.health > 0 && ahead > -3 && ahead < 85
            model.position = [Float(threat.lane) * 2.4, threat.obstacle ? 0.35 : 0.9, -ahead]
        }
    }

    func restart() {
        mission = Mission()
        firing = false
        started = true
        render()
    }
}

struct GameView: View {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastFrame: Date?

    var body: some View {
        ZStack {
            RealityView { content in
                session.build()
                content.add(session.world)
            }
            .ignoresSafeArea()
            .gesture(DragGesture(minimumDistance: 25).onEnded { value in
                guard session.started else { return }
                if abs(value.translation.width) > abs(value.translation.height) {
                    session.mission.move(value.translation.width > 0 ? 1 : -1)
                } else if value.translation.height < 0 { session.mission.jump() }
            })
            VStack(spacing: 12) {
                HStack {
                    Text("LAST LINE").font(.headline).tracking(4)
                    Spacer()
                    Button(session.mission.paused ? "Resume" : "Pause") {
                        session.firing = false
                        session.mission.paused.toggle()
                    }
                    .disabled(!session.started || session.mission.terminal)
                }
                HStack {
                    Label("\(session.mission.health)", systemImage: "cross.fill")
                    ProgressView(value: Double(session.mission.health), total: 100).tint(.green)
                    Text(session.mission.recruited ? "ALLY +1" : "SOLO").font(.caption.bold())
                }
                Text(session.mission.objective).font(.headline)
                ProgressView(value: min(session.mission.distance, 225), total: 225).tint(.yellow)
                Spacer()
                if session.mission.phase == .camp {
                    Text("Release fire for cover · Switch lanes to target defenders")
                        .font(.caption).padding(10).background(.black.opacity(0.7), in: Capsule())
                }
                HStack(alignment: .bottom) {
                    VStack {
                        HStack {
                            Button { session.mission.move(-1) } label: { Image(systemName: "arrow.left") }
                            Button { session.mission.move(1) } label: { Image(systemName: "arrow.right") }
                        }
                        Button("Jump") { session.mission.jump() }
                    }
                    Spacer()
                    VStack(spacing: 16) {
                        Button(session.mission.reloading ? "Reloading…" : "\(session.mission.ammo) / \(session.mission.reserve)") { session.mission.reload() }
                        Text("FIRE")
                            .font(.headline).frame(width: 92, height: 92)
                            .background(.black.opacity(0.7), in: Circle())
                            .overlay(Circle().stroke(.yellow, lineWidth: 2))
                            .gesture(DragGesture(minimumDistance: 0)
                                .onChanged { _ in session.firing = true }
                                .onEnded { _ in session.firing = false })
                            .accessibilityLabel("Fire; hold to shoot")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { session.firing = true }
                    }
                }
                .buttonStyle(.borderedProminent).tint(.black.opacity(0.7))
                Text("PROTOTYPE • CRASH VALLEY").font(.caption2).tracking(2)
            }
            .padding(20).foregroundStyle(.white)
            .background(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.8), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 230).ignoresSafeArea()
            }
            if !session.started || session.mission.terminal {
                Color.black.opacity(0.8).ignoresSafeArea()
                VStack(spacing: 20) {
                    Text(session.started ? session.mission.objective : "LAST LINE").font(.largeTitle.bold())
                    Text(session.started ? "Shots: \(session.mission.shots) · Hits: \(session.mission.hits)" : "Survive the crash. Capture Ridge Camp. Bring an ally home.")
                        .multilineTextAlignment(.center)
                    Text("Swipe or use arrows to dodge. Hold FIRE to shoot enemies in your lane. At camp, release FIRE to take cover.")
                        .font(.callout).multilineTextAlignment(.center)
                    Button(session.started ? "Retry mission" : "Begin mission") {
                        session.restart()
                        lastFrame = nil
                    }.buttonStyle(.borderedProminent).tint(.orange)
                }.foregroundStyle(.white).padding(32).frame(maxWidth: 500)
            } else if session.mission.paused {
                Text("PAUSED").font(.largeTitle.bold()).foregroundStyle(.white)
                    .padding(30).background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .onReceive(Timer.publish(every: 1.0 / 60, on: .main, in: .common).autoconnect()) { now in
            defer { lastFrame = now }
            guard session.started, let previous = lastFrame else { return }
            session.mission.tick(seconds: now.timeIntervalSince(previous), firing: session.firing)
            session.render()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                session.mission.paused = true
                session.firing = false
            }
            lastFrame = nil
        }
    }
}
