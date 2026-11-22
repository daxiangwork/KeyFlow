import AppKit
import SwiftUI

enum ActionsRingToastKind {
    case info, success, warning, error

    var textColor: Color {
        switch self {
        case .info: KeyFlowTheme.text
        case .success: KeyFlowTheme.success
        case .warning: KeyFlowTheme.warning
        case .error: KeyFlowTheme.error
        }
    }

    var backgroundColor: Color {
        switch self {
        case .info: KeyFlowTheme.surface
        case .success: Color(hex: 0xE8F6F2)
        case .warning: Color(hex: 0xFBF3E8)
        case .error: Color(hex: 0xFBECEC)
        }
    }

    var icon: String {
        switch self {
        case .info: "info.circle"
        case .success: "checkmark.circle.fill"
        case .warning, .error: "exclamationmark.triangle.fill"
        }
    }
}

@MainActor
final class ActionsRingController: ObservableObject {
    @Published private(set) var isVisible = false

    var onSelect: ((RingItem) -> Void)?
    private var panel: NSPanel?
    private var toastPanel: NSPanel?
    private var toastWorkItem: DispatchWorkItem?
    private var mouseMonitors: [Any] = []
    private var keyMonitors: [Any] = []
    private var ringItems: [RingItem] = []

    func show(items: [RingItem]) {
        close()
        ringItems = items
        let origin = Self.clampedOrigin(for: NSEvent.mouseLocation, size: CGSize(width: 600, height: 600))
        let panel = makePanel(frame: CGRect(origin: origin, size: CGSize(width: 600, height: 600)))
        let content = NSHostingView(rootView: ActionsRingView(
            items: items,
            onSelect: { [weak self] item in self?.select(item) },
            onClose: { [weak self] in self?.close() },
            animateAppearance: true
        ))
        content.alphaValue = 0
        panel.contentView = content
        panel.orderFrontRegardless()
        self.panel = panel
        isVisible = true
        installMonitors()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            content.animator().alphaValue = 1
        }
    }

    func close() {
        removeMonitors()
        panel?.close()
        panel = nil
        ringItems = []
        isVisible = false
    }

    func showToast(_ text: String, kind: ActionsRingToastKind, duration: Double = 4) {
        toastWorkItem?.cancel()
        toastPanel?.close()
        toastPanel = nil
        let origin = NSEvent.mouseLocation
        let toast = RingToastView(text: text, kind: kind) { [weak self] in self?.closeToast() }
        let host = NSHostingView(rootView: toast)
        let fitting = host.fittingSize
        let size = CGSize(width: min(max(fitting.width, 220), 360), height: fitting.height)
        let panel = makePanel(frame: CGRect(origin: Self.toastOrigin(for: origin, size: size), size: size))
        panel.contentView = host
        panel.orderFrontRegardless()
        toastPanel = panel

        let work = DispatchWorkItem { [weak self] in self?.closeToast() }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func select(_ item: RingItem) {
        close()
        onSelect?(item)
    }

    private func closeToast() {
        toastWorkItem?.cancel()
        toastWorkItem = nil
        toastPanel?.close()
        toastPanel = nil
    }

    private func makePanel(frame: CGRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.isMovable = false
        return panel
    }

    private func installMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handleMouseDown(event)
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: handler) {
            mouseMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { event in
            handler(event)
            return event
        }) {
            mouseMonitors.append(monitor)
        }
        let keyHandler: (NSEvent) -> Void = { [weak self] event in
            if event.keyCode == 53 { self?.close() }
        }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyHandler) {
            keyMonitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            keyHandler(event)
            return event
        }) {
            keyMonitors.append(monitor)
        }
    }

    private func removeMonitors() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        keyMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
        keyMonitors.removeAll()
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let panel else { return }
        let point = NSEvent.mouseLocation
        if !interactiveFrames(for: panel, items: ringItems).contains(where: { $0.contains(point) }) {
            close()
        }
    }

    private func interactiveFrames(for panel: NSPanel, items: [RingItem]) -> [CGRect] {
        let origin = panel.frame.origin
        var frames = [CGRect(x: origin.x + 282, y: origin.y + 282, width: 36, height: 36)]
        for (index, _) in items.enumerated() {
            let angle = Double(index) * 360 / Double(items.count)
            let radians = (angle - 90) * .pi / 180
            let center = CGPoint(x: origin.x + 300 + 86 * cos(radians), y: origin.y + 300 + 86 * sin(radians))
            frames.append(CGRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60))
        }
        return frames
    }

    private static func clampedOrigin(for point: CGPoint, size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return CGPoint(x: point.x - 300, y: point.y - 300) }
        let menuInset = visible == screen?.frame ? NSStatusBar.system.thickness : 0
        let minX = visible.minX + 12
        let maxX = visible.maxX - size.width - 12
        let minY = visible.minY + 12
        let maxY = visible.maxY - size.height - 12 - menuInset
        return CGPoint(
            x: min(max(point.x - size.width / 2, minX), maxX),
            y: min(max(point.y - size.height / 2, minY), maxY)
        )
    }

    private static func toastOrigin(for point: CGPoint, size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return CGPoint(x: point.x + 24, y: point.y - 24) }
        return CGPoint(
            x: min(max(point.x + 24, visible.minX + 12), visible.maxX - size.width - 12),
            y: min(max(point.y - size.height - 24, visible.minY + 12), visible.maxY - size.height - 12)
        )
    }
}

private struct RingToastView: View {
    let text: String
    let kind: ActionsRingToastKind
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: kind.icon)
                Text(text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 320, alignment: .leading)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(kind.textColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(kind.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(KeyFlowTheme.border))
            .shadow(color: .black.opacity(0.14), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
    }
}
