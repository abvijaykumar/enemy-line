import SwiftUI
import LastLineCore

struct GameView: View {
    @ObservedObject var session: GameSession
    @Binding var showingSettings: Bool
    @FocusState private var keyboardFocused: Bool
    @State private var showingHelp = false
    @State private var damageFlash = false

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 520
            ZStack {
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 25).onEnded { value in
                        guard !session.mission.paused, !session.mission.terminal else { return }
                        if abs(value.translation.width) > abs(value.translation.height) {
                            session.mission.move(value.translation.width > 0 ? 1 : -1)
                        } else if value.translation.height < 0 { session.mission.jump() }
                        else { session.mission.slide() }
                    })
                LinearGradient(colors: [.black.opacity(0.8), .clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    .allowsHitTesting(false).ignoresSafeArea()
                if damageFlash { Color.red.opacity(0.22).ignoresSafeArea().allowsHitTesting(false) }
                Image(systemName: "plus").font(.title2.weight(.ultraLight))
                    .foregroundStyle(session.mission.targetID == nil ? .white.opacity(0.65) : TacticalStyle.amber)
                    .offset(x: CGFloat(reticleLane) * min(geometry.size.width / 4, 100))
                    .allowsHitTesting(false)
                VStack(spacing: compact ? 5 : 12) {
                    header
                    if !compact {
                        CheckpointStrip(distance: session.mission.distance)
                        Text(session.mission.objective).font(.headline).multilineTextAlignment(.center)
                        Text(status).font(.caption.bold()).foregroundStyle(TacticalStyle.amber)
                    }
                    Spacer(minLength: 8)
                    if let warning = session.mission.warning {
                        Text(warning).font(.caption.bold()).padding(10)
                            .foregroundStyle(.black).background(TacticalStyle.amber, in: Capsule())
                    }
                    if session.mission.phase == .camp && !compact {
                        Label(session.firing || (session.settings.autoFire && session.mission.targetID != nil) ? "ENGAGING" : "IN COVER", systemImage: "shield.fill")
                            .font(.caption.bold()).padding(.horizontal, 18).padding(.vertical, 10)
                            .background(session.firing ? TacticalStyle.panel : TacticalStyle.olive, in: Capsule())
                        Text("Release FIRE for cover · Clear all defenders")
                            .font(.caption2).foregroundStyle(.white.opacity(0.9))
                    }
                    controls(compact: compact)
                }.padding(compact ? 12 : 20)
                if session.mission.terminal { results }
                else if session.mission.paused { pauseMenu }
            }
        }
        .foregroundStyle(.white)
        .focusable().focused($keyboardFocused)
        .onAppear { keyboardFocused = true }
        .onChange(of: keyboardFocused) { _, focused in if !focused { session.firing = false } }
        .onKeyPress(phases: [.down, .up]) { press in
            if press.key == .escape {
                if press.phase == .down { if session.mission.paused { session.unpause() } else { session.pause() } }
                return .handled
            }
            guard !session.mission.paused, !session.mission.terminal, !showingSettings, !showingHelp else { return .ignored }
            if press.key == .space { session.firing = press.phase == .down; return .handled }
            guard press.phase == .down else { return .ignored }
            switch press.key {
            case .leftArrow, "a": session.mission.move(-1)
            case .rightArrow, "d": session.mission.move(1)
            case .upArrow, "w": session.mission.jump()
            case .downArrow, "s": session.mission.slide()
            case "r": session.mission.reload()
            case "g": session.grenade()
            default: return .ignored
            }
            return .handled
        }
        .task(id: session.settings.batterySaver) {
            var previous = Date()
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: session.settings.batterySaver ? 33_333_333 : 16_666_667) }
                catch { break }
                let now = Date()
                session.tick(now.timeIntervalSince(previous))
                previous = now
            }
        }
        .onChange(of: session.mission.damageSerial) { _, _ in
            guard !session.settings.reducedMotion else { return }
            damageFlash = true
        }
        .task(id: session.mission.damageSerial) {
            try? await Task.sleep(nanoseconds: 140_000_000)
            if !Task.isCancelled { damageFlash = false }
        }
        .onChange(of: session.mission.paused) { _, _ in session.firing = false }
        .sheet(isPresented: $showingHelp) { HelpView() }
        .onDisappear { session.firing = false }
    }

    private var reticleLane: Int {
        if let target = session.mission.targetID,
           let threat = session.mission.threats.first(where: { $0.id == target }) { return threat.lane }
        return session.mission.aimLane
    }
    private var status: String {
        switch session.mission.phase {
        case .camp: return "\(session.mission.campDefenders) DEFENDERS LEFT"
        case .extraction: return "\(max(0, Int(225 - session.mission.distance))) m TO EXTRACTION · ALLY RESCUED"
        default: return "\(max(0, Int(120 - session.mission.distance))) m TO CAMP"
        }
    }
    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ENEMY LINE").font(.caption.bold()).tracking(2)
                HStack {
                    Image(systemName: "cross.fill")
                    ProgressView(value: Double(session.mission.health), total: 100).tint(.green).frame(maxWidth: 140)
                    Text("\(session.mission.health)").font(.caption.monospacedDigit())
                }.accessibilityElement(children: .ignore).accessibilityLabel("Health \(session.mission.health) percent")
            }
            Spacer()
            Label("\(session.mission.squadSize)", systemImage: "person.2.fill").font(.caption.bold())
                .accessibilityLabel("\(session.mission.squadSize) squad members")
            Button { session.pause() } label: {
                Image(systemName: "pause.fill").frame(width: 44, height: 44).background(TacticalStyle.panel, in: Circle())
            }.accessibilityLabel("Pause")
        }
    }
    private func controls(compact: Bool) -> some View {
        HStack(alignment: .bottom) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TacticalControl(symbol: "chevron.left", label: "Move left") { session.mission.move(-1) }
                    TacticalControl(symbol: "chevron.right", label: "Move right") { session.mission.move(1) }
                }
                if session.mission.phase != .camp {
                    HStack(spacing: 8) {
                        TacticalControl(symbol: "arrow.up", label: "Jump") { session.mission.jump() }
                        TacticalControl(symbol: "arrow.down", label: "Slide") { session.mission.slide() }
                    }
                }
            }
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Button { session.grenade() } label: {
                        Label("\(session.mission.grenades)", systemImage: "burst.fill").frame(minWidth: 56, minHeight: 44)
                            .background(TacticalStyle.panel, in: Capsule())
                    }.accessibilityLabel("Throw grenade; \(session.mission.grenades) remaining")
                        .disabled(session.mission.grenades == 0)
                Button { session.mission.reload() } label: {
                    Text(session.mission.reloading ? "RELOADING…" : "\(session.mission.ammo) / \(session.mission.reserve)")
                        .font(.caption.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.6).frame(minWidth: 90, minHeight: 44)
                        .background(TacticalStyle.panel, in: Capsule())
                }.accessibilityLabel("Reload; \(session.mission.ammo) rounds loaded, \(session.mission.reserve) in reserve")
                }
                FireControl(firing: $session.firing, aim: { session.mission.aim(at: $0) }, baseLane: session.mission.lane, compact: compact)
            }
        }
        .buttonStyle(.plain)
        .disabled(session.mission.paused || session.mission.terminal)
    }
    private var pauseMenu: some View {
        modalPanel {
            Text("PAUSED").font(.largeTitle.bold())
            Text(session.mission.operation.title).foregroundStyle(.secondary)
            menuButton("Resume", prominent: true) { session.unpause(); keyboardFocused = true }
            menuButton("Settings") { showingSettings = true }
            menuButton("Field manual") { showingHelp = true }
            menuButton("Save & return to operations") { session.leave() }
        }
    }
    private var results: some View {
        modalPanel {
            Image(systemName: session.mission.phase == .victory ? "checkmark.shield.fill" : "cross.case.fill")
                .font(.system(size: 48)).foregroundStyle(TacticalStyle.amber)
            Text(session.mission.objective).font(.title.bold()).multilineTextAlignment(.center)
            Text(session.mission.phase == .victory ? "\(session.mission.squadSize) allies heading home." : "Return to your last checkpoint and try a different approach.")
                .multilineTextAlignment(.center)
            HStack {
                resultStat("TIME", "\(Int(session.mission.elapsed))s")
                Spacer()
                resultStat("ACCURACY", "\(Int(session.mission.accuracy * 100))%")
                Spacer()
                resultStat("ELIMINATED", "\(session.mission.kills)")
            }.padding(.vertical, 12)
            if session.mission.phase == .defeated {
                menuButton("Retry checkpoint", prominent: true) { session.retryCheckpoint() }
            } else if let next = MissionOperation(rawValue: session.mission.operation.rawValue + 1) {
                menuButton("Next: \(next.title)", prominent: true) { session.start(next) }
            } else {
                Text("CAMPAIGN COMPLETE").font(.caption.bold()).foregroundStyle(TacticalStyle.amber)
            }
            menuButton("Replay mission") { session.start(session.mission.operation) }
            menuButton("Operations") { session.leave() }
        }
    }
    private func modalPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            Color.black.opacity(0.9).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 18, content: content).padding(28).frame(maxWidth: 480).frame(maxWidth: .infinity)
            }.defaultScrollAnchor(.center)
        }
    }
    private func menuButton(_ title: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(prominent ? .black : .white)
                .background(prominent ? TacticalStyle.amber : TacticalStyle.panel, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
    private func resultStat(_ label: String, _ value: String) -> some View {
        VStack { Text(value).font(.title3.bold()); Text(label).font(.system(size: 9, weight: .bold)) }
    }
}
