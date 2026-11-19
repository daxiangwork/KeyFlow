import SwiftUI
import UniformTypeIdentifiers

struct ActionsRingView: View {
    let rules: [SmartRule]
    var selectedRuleID: UUID?
    let onSelect: (SmartRule) -> Void
    let onClose: () -> Void
    var onDropRule: (@Sendable (UUID, Int) -> Void)? = nil
    var animateAppearance = false
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                let angle = Double(index) * 360 / Double(rules.count)
                let radians = (angle - 90) * .pi / 180
                let x = 300 + 86 * cos(radians)
                let y = 300 + 86 * sin(radians)
                RingSlot(
                    rule: rule,
                    isSelected: selectedRuleID == rule.id,
                    action: { onSelect(rule) }
                )
                .position(x: isExpanded ? x : 300, y: isExpanded ? y : 300)
                .scaleEffect(isExpanded ? 1 : 0.72)
                .opacity(isExpanded ? 1 : 0)
                .zIndex(Double(index) + 1)
                .onDrop(of: [.text], delegate: RingSlotDropDelegate(index: index, handler: onDropRule))
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x3A3A3A))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0xE8E8E8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.black.opacity(0.08)))
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .position(x: 300, y: 300)
            .scaleEffect(isExpanded ? 1 : 0.85)
            .opacity(isExpanded ? 1 : 0)
            .zIndex(100)
            .accessibilityLabel("关闭")
        }
        .frame(width: 600, height: 600)
        .accessibilityElement(children: .contain)
        .onAppear {
            if animateAppearance {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
                    isExpanded = true
                }
            } else {
                isExpanded = true
            }
        }
    }
}

private struct RingSlot: View {
    let rule: SmartRule
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: rule.actions.first?.kind.systemImage ?? "sparkles")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22, alignment: .center)
                .foregroundStyle(.white)
        }
        .buttonStyle(RingCircleButtonStyle(isEmphasized: isHovering || isSelected))
        .onHover { isHovering = $0 }
        .accessibilityLabel(rule.name)
    }
}

private struct RingCircleButtonStyle: ButtonStyle {
    let isEmphasized: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 48, height: 48, alignment: .center)
            .background(KeyFlowTheme.text)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(KeyFlowTheme.text, lineWidth: 2)
                    .padding(-3)
                    .opacity(isEmphasized && !configuration.isPressed ? 1 : 0)
            }
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .padding(3)
                    .opacity(configuration.isPressed ? 1 : 0)
            }
            .shadow(color: .black.opacity(0.2), radius: 8, y: 6)
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }
}

struct RingSlotDropDelegate: DropDelegate {
    let index: Int
    let handler: (@Sendable (UUID, Int) -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        handler != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let handler else { return false }
        for provider in info.itemProviders(for: [.text]) {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let string = object as? String, let id = UUID(uuidString: string) else { return }
                DispatchQueue.main.async { handler(id, index) }
            }
        }
        return true
    }
}
