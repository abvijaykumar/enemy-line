import SwiftUI
import LastLineCore

struct CampaignView: View {
    @ObservedObject var session: GameSession
    @Binding var showingSettings: Bool
    @State private var selected: MissionOperation = .crashValley
    @State private var showingHelp = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.95)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ENEMY LINE").font(.system(size: 38, weight: .black, design: .rounded)).minimumScaleFactor(0.65).lineLimit(1)
                            Text("BEHIND THE LINE").font(.caption).tracking(5).foregroundStyle(TacticalStyle.amber)
                        }
                        Spacer()
                        Button { showingSettings = true } label: { Image(systemName: "gearshape.fill").frame(width: 44, height: 44) }
                            .accessibilityLabel("Settings")
                    }
                    Text("Your squad is gone. Your mission isn't.")
                        .font(.title3.bold()).padding(.top, 28)
                    if session.campaign.checkpoint != nil {
                        Button { session.resume() } label: {
                            Label("Continue saved mission", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 48)
                        }.buttonStyle(.bordered).tint(TacticalStyle.amber)
                    }
                    Text("OPERATIONS").font(.caption.bold()).tracking(3).foregroundStyle(.secondary)
                    ForEach(MissionOperation.allCases) { operation in
                        let unlocked = operation.rawValue <= session.campaign.unlocked
                        Button { selected = operation } label: {
                            HStack(spacing: 14) {
                                Image(systemName: unlocked ? ["figure.run", "car.side.fill", "helicopter.fill"][operation.rawValue] : "lock.fill")
                                    .font(.title2).frame(width: 38)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("0\(operation.rawValue + 1) / \(operation.title.uppercased())").font(.headline)
                                    if let record = session.campaign.records[operation.rawValue] {
                                        Text("Best \(Int(record.seconds))s · \(Int(record.accuracy * 100))% accuracy").font(.caption)
                                    } else { Text(unlocked ? operation.campName : "Complete the previous operation").font(.caption) }
                                }
                                Spacer(minLength: 0)
                                if selected == operation { Image(systemName: "checkmark.circle.fill").foregroundStyle(TacticalStyle.amber) }
                            }
                            .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                            .background(TacticalStyle.panel, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected == operation ? TacticalStyle.amber : .white.opacity(0.15)))
                        }.buttonStyle(.plain).disabled(!unlocked).opacity(unlocked ? 1 : 0.55)
                    }
                    Text(selected.briefing).font(.callout).foregroundStyle(.white.opacity(0.85))
                    HStack {
                        objective("waveform.path.ecg", "SURVIVE")
                        Spacer()
                        objective("flag.fill", "CAPTURE")
                        Spacer()
                        objective("helicopter.fill", "EXTRACT")
                    }.padding(.vertical, 8)
                    Button { session.start(selected) } label: {
                        HStack { Text("BEGIN MISSION"); Spacer(); Image(systemName: "arrow.right") }
                            .font(.headline).padding(18).foregroundStyle(.black)
                            .background(TacticalStyle.amber, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                    Button("How to play") { showingHelp = true }.frame(maxWidth: .infinity, minHeight: 44)
                }.padding(24).frame(maxWidth: 620)
                    .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .onAppear { selected = MissionOperation(rawValue: session.campaign.unlocked) ?? .crashValley }
        .sheet(isPresented: $showingHelp) { HelpView() }
    }

    private func objective(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(TacticalStyle.amber)
            Text(title).font(.caption2.bold()).tracking(2)
        }
    }
}

struct SettingsView: View {
    @ObservedObject var session: GameSession
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Gameplay · applies to new missions") {
                    Picker("Difficulty", selection: $session.settings.difficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                }
                Section("Controls") {
                    Toggle("Aim assistance", isOn: $session.settings.aimAssist)
                    Toggle("Automatic fire on visible targets", isOn: $session.settings.autoFire)
                    Text("Drag horizontally on FIRE to aim between lanes. Assistance selects another visible enemy when your lane is clear.").font(.caption)
                }
                Section("Sound and comfort") {
                    Toggle("Sound effects", isOn: $session.settings.sound)
                    #if os(iOS)
                    Toggle("Haptic feedback", isOn: $session.settings.haptics)
                    #endif
                    Toggle("Reduce character motion", isOn: $session.settings.reducedMotion)
                    Toggle("Battery saver · fewer motion updates", isOn: $session.settings.batterySaver)
                }
                Section("Progress") {
                    Text("Progress is saved on this device. No account or internet connection is required.")
                    Button("Reset campaign", role: .destructive) { confirmReset = true }.disabled(session.playing)
                }
                Section("About") {
                    Text("Enemy Line · Offline first release")
                    Text("A single-player campaign. No account, ads, or network required.").font(.caption)
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { session.save(); dismiss() } } }
            .confirmationDialog("Delete all mission progress on this device?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset campaign", role: .destructive) { session.resetCampaign() }
            }
            .onDisappear { session.save() }
        }
    }
}

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Move") {
                    Text("You run forward automatically. Swipe left or right to change lanes. Swipe up to jump low barriers, down to slide under overhead beams. The on-screen buttons do the same.")
                }
                Section("Fight") {
                    Text("Hold FIRE to shoot. Drag left or right on FIRE to aim. Tap ammunition to reload. Grenades damage enemies across all lanes ahead of you. Resources are limited.")
                }
                Section("Capture") {
                    Text("At camp, your officer stops behind cover. Release FIRE to stay protected. Clear every defender to recruit an ally, restore health, and resupply ammunition.")
                }
                Section("Keyboard") { Text("A/D or ←/→: move · W/↑: jump · S/↓: slide · Space: hold fire · R: reload · G: grenade · Escape: pause") }
                Section("Controller") { Text("D-pad: move · A: jump · B: slide · X: reload · Right trigger: fire · Left shoulder: grenade · Menu: pause") }
                Section("Save") { Text("Continue resumes your latest autosave. After defeat, Retry checkpoint returns to the last mission milestone. Missions unlock in sequence.") }
            }
            .navigationTitle("Field manual")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
