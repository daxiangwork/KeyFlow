import AppKit
import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

enum KeyFlowTheme {
    static let canvas = Color(hex: 0xFAFAFA)
    static let surface = Color(hex: 0xFFFFFF)
    static let sidebar = Color(hex: 0xFAFAFA)
    static let border = Color(hex: 0xE6E6E6)
    static let text = Color(hex: 0x1A1A1A)
    static let secondaryText = Color(hex: 0x6B6B6B)
    static let accent = Color(hex: 0x1A1A1A)
    static let accentHover = Color.black
    static let accentSoft = Color(hex: 0xF0F0F0)
    static let success = Color(hex: 0x1C9C85)
    static let warning = Color(hex: 0xA8611B)
    static let error = Color(hex: 0xB84242)

    static let smallSpacing: CGFloat = 8
    static let spacing: CGFloat = 16
    static let largeSpacing: CGFloat = 24
    static let accentGradient = LinearGradient(colors: [accent, accent], startPoint: .top, endPoint: .bottom)
}

struct KeyFlowBackground: View {
    var body: some View {
        KeyFlowTheme.canvas.ignoresSafeArea()
    }
}

struct GlassSurface: ViewModifier {
    var cornerRadius: CGFloat = 12
    var borderColor = KeyFlowTheme.border

    func body(content: Content) -> some View {
        content
            .background(KeyFlowTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(borderColor, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
    }
}

extension View {
    func glassSurface(cornerRadius: CGFloat = 12) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? Color(hex: 0x111111) : isHovering ? .black : KeyFlowTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovering = $0 }
            .accessibilityElement(children: .combine)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(KeyFlowTheme.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isHovering || configuration.isPressed ? KeyFlowTheme.accentSoft : KeyFlowTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KeyFlowTheme.border))
            .opacity(isEnabled ? 1 : 0.45)
            .onHover { isHovering = $0 }
            .accessibilityElement(children: .combine)
    }
}

struct IconActionButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isHovering ? KeyFlowTheme.text : KeyFlowTheme.secondaryText)
            .background(isHovering ? KeyFlowTheme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onHover { isHovering = $0 }
    }
}

struct ActionIconView: View {
    let name: String
    var size: CGFloat = 20

    var body: some View {
        Image(systemName: name)
            .symbolRenderingMode(.monochrome)
            .font(.system(size: size, weight: .light))
            .frame(width: size, height: size, alignment: .center)
    }
}

struct RingItemIconView: View {
    let item: RingItem?
    var size: CGFloat = 22

    var body: some View {
        if let data = item?.customImageData, let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size, height: size, alignment: .center)
        } else {
            RingIconGlyphView(icon: item?.icon ?? "plus", size: size)
        }
    }
}

struct RingIconGlyphView: View {
    let icon: String
    var size: CGFloat = 22

    var body: some View {
        if icon.hasPrefix("asset:") {
            let assetPath = String(icon.dropFirst(6))
            let url = Bundle.main.resourceURL?
                .appendingPathComponent("Icons")
                .appendingPathComponent(assetPath)
                .appendingPathExtension("svg")
            if let url, let image = bundledTemplateImage(at: url) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: size, height: size, alignment: .center)
            } else {
                ActionIconView(name: "questionmark.circle", size: size)
            }
        } else {
            ActionIconView(name: icon, size: size)
        }
    }
}

private func bundledTemplateImage(at url: URL) -> NSImage? {
    guard let image = NSImage(contentsOf: url) else { return nil }
    image.isTemplate = true
    return image
}

struct AssetImage: View {
    let name: String
    var ext = "png"

    var body: some View {
        if let path = Bundle.main.path(forResource: name, ofType: ext), let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "computermouse")
                .resizable()
        }
    }
}

struct AppIconView: View {
    var size: CGFloat = 40

    var body: some View {
        AssetImage(name: "AppIcon")
            .frame(width: size, height: size)
            .accessibilityLabel("KeyFlow")
    }
}

struct StatusDot: View {
    let isActive: Bool
    var warning = false

    var body: some View {
        Circle()
            .fill(isActive ? KeyFlowTheme.success : warning ? KeyFlowTheme.warning : KeyFlowTheme.secondaryText.opacity(0.4))
            .frame(width: 8, height: 8)
            .shadow(color: isActive ? KeyFlowTheme.success.opacity(0.16) : .clear, radius: 3)
            .accessibilityHidden(true)
    }
}

struct SmartActionsToggle: View {
    @ObservedObject var state: AppState
    var disabledWhenDisconnected = true

    var body: some View {
        Toggle("启用 Smart Actions", isOn: Binding(
            get: { state.isServiceEnabled },
            set: { state.setServiceEnabled($0) }
        ))
        .toggleStyle(.switch)
        .tint(KeyFlowTheme.accent)
        .disabled(!state.inputMonitoringGranted || !state.accessibilityGranted || (disabledWhenDisconnected && !state.monitor.isConnected))
    }
}

struct InlineMessage: View {
    let text: String
    var isError = false
    var isWarning = false

    var body: some View {
        let color = isError ? KeyFlowTheme.error : isWarning ? KeyFlowTheme.warning : KeyFlowTheme.secondaryText
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError || isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 13))
        .foregroundStyle(color)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isError ? KeyFlowTheme.error.opacity(0.08) : isWarning ? KeyFlowTheme.warning.opacity(0.08) : KeyFlowTheme.accentSoft.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(color.opacity(0.16)))
    }
}
