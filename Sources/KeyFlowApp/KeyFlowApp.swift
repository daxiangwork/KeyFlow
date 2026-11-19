import AppKit
import SwiftUI

@main
struct KeyFlowApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window(windowTitle, id: "main") {
            MainWindow(state: state)
                .frame(minWidth: 920, minHeight: 640)
                .preferredColorScheme(.light)
        }
        .defaultSize(width: 1080, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            Button("打开 KeyFlow") { showMainWindow() }
            Divider()
            Toggle("启用 Smart Actions", isOn: Binding(
                get: { state.isServiceEnabled },
                set: { state.setServiceEnabled($0) }
            ))
            .disabled(!state.inputMonitoringGranted || !state.accessibilityGranted)
            Text(state.monitor.isConnected ? "JZ M5 已连接" : "JZ M5 未连接")
            if state.monitor.isConnected {
                Text(state.battery.menuTitle)
                    .foregroundStyle(menuBatteryColor)
                    .help(state.battery.menuDetail)
            }
            Divider()
            Button("退出 KeyFlow") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: state.isServiceEnabled ? "computermouse.fill" : "computermouse")
                .symbolRenderingMode(.monochrome)
                .imageScale(.small)
                .accessibilityLabel("KeyFlow")
        }
        .menuBarExtraStyle(.menu)
    }

    private var windowTitle: String {
        switch state.currentPage {
        case .home: ""
        case .smartActions: "KeyFlow"
        case .settings: "设置"
        case .actionsRing: "Actions Ring"
        }
    }

    private var menuBatteryColor: Color {
        guard let reading = state.battery.reading else { return KeyFlowTheme.secondaryText }
        return reading.percent <= 20 ? KeyFlowTheme.warning : KeyFlowTheme.text
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
