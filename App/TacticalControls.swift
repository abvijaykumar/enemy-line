import SwiftUI

enum TacticalStyle {
    static let amber = Color(red: 1, green: 0.71, blue: 0.20)
    static let olive = Color(red: 0.24, green: 0.36, blue: 0.17)
    static let panel = Color.black.opacity(0.72)
}

struct TacticalControl: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.bold()).foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(TacticalStyle.panel, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct FireControl: View {
    @Binding var firing: Bool
    @GestureState private var held = false
    @State private var accessibleFiring = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "scope").font(.title)
            Text("FIRE").font(.caption.bold())
        }
        .foregroundStyle(TacticalStyle.amber)
        .frame(width: 96, height: 96)
        .background(held || accessibleFiring ? TacticalStyle.olive : TacticalStyle.panel, in: Circle())
        .overlay(Circle().stroke(TacticalStyle.amber, lineWidth: 3))
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0).updating($held) { _, state, _ in state = true })
        .onChange(of: held) { _, value in firing = value || accessibleFiring }
        .onChange(of: firing) { _, value in if !value { accessibleFiring = false } }
        .onDisappear { firing = false; accessibleFiring = false }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fire")
        .accessibilityValue(accessibleFiring ? "Firing" : "Stopped")
        .accessibilityHint("Double tap to start or stop firing")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            accessibleFiring.toggle()
            firing = accessibleFiring
        }
    }
}

struct CheckpointStrip: View {
    let distance: Double

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { checkpoint in
                if checkpoint > 0 {
                    Rectangle().fill(.white.opacity(0.5)).frame(width: 38, height: 1)
                }
                Circle()
                    .fill(distance >= [0.0, 120.0, 225.0][checkpoint] ? TacticalStyle.amber : TacticalStyle.panel)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mission progress")
        .accessibilityValue("\(min(100, Int(distance / 225 * 100))) percent")
    }
}
