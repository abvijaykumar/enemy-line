import SwiftUI
import RealityKit

@main
struct LastLineApp: App {
    var body: some Scene {
        WindowGroup { EnemyLineRoot() }
    }
}

struct EnemyLineRoot: View {
    @StateObject private var session = GameSession()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    var body: some View {
        ZStack {
            if session.playing {
                RealityView { content in
                    #if os(iOS)
                    content.camera = .virtual
                    #endif
                    session.renderer.reset(session.mission)
                    content.add(session.renderer.root)
                }
                .background(Color(red: 0.4, green: 0.51, blue: 0.54))
                .ignoresSafeArea()
                GameView(session: session, showingSettings: $showingSettings)
            } else {
                GeometryReader { geometry in
                    Image("BriefingBackdrop").resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                }.ignoresSafeArea()
                CampaignView(session: session, showingSettings: $showingSettings)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) { SettingsView(session: session) }
        .alert("Save notice", isPresented: Binding(get: { session.notice != nil }, set: { if !$0 { session.notice = nil } })) {
            Button("OK") { session.notice = nil }
        } message: { Text(session.notice ?? "") }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { session.pause(); session.save() }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 600)
        #endif
    }
}
