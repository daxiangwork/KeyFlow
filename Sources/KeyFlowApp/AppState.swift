import AppKit
import CoreGraphics
import Foundation

enum AppPage {
    case home
    case smartActions
    case settings
    case actionsRing
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentPage: AppPage = .home
    @Published private(set) var isServiceEnabled = false
    @Published private(set) var inputMonitoringGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var statusMessage = "KeyFlow 尚未启用"

    let store = RuleStore()
    let monitor = HIDMonitor()
    let engine = ActionEngine()
    let battery = BatteryMonitor()
    let ringStore = ActionsRingStore()
    let ringController = ActionsRingController()
    private let interceptor: EventInterceptor

    init() {
        interceptor = EventInterceptor(registry: monitor.suppressionRegistry)
        monitor.onTrigger = { [weak self] button, gesture in
            self?.handleTrigger(button: button, gesture: gesture)
        }
        ringController.onSelect = { [weak self] rule in
            self?.executeFromRing(rule)
        }
        engine.showActionsRing = { [weak self] in
            self?.openActionsRing()
        }
        refreshPermissions()
        if inputMonitoringGranted && accessibilityGranted {
            _ = interceptor.start()
        }
        monitor.start()
        battery.start()
    }

    func setServiceEnabled(_ enabled: Bool) {
        if enabled {
            refreshPermissions()
            guard monitor.isConnected else {
                statusMessage = "无法启用：请先用有线或 2.4G 接收器连接 JZ M5。"
                return
            }
            guard inputMonitoringGranted && accessibilityGranted else {
                statusMessage = "无法启用：请先完成输入监控和辅助功能授权。"
                return
            }
            guard interceptor.start() else {
                statusMessage = "无法启用事件拦截。请重新授权辅助功能后重试。"
                return
            }
            isServiceEnabled = true
            HIDInputRouter.shared.setSuppressionEnabled(true)
            statusMessage = "正在运行 · 鼠标动作会被转换为 Smart Actions"
        } else {
            isServiceEnabled = false
            HIDInputRouter.shared.setSuppressionEnabled(false)
            ringController.close()
            monitor.resetTriggers()
            statusMessage = "KeyFlow 已暂停，鼠标恢复原始行为"
        }
    }

    func refreshPermissions() {
        inputMonitoringGranted = CGPreflightListenEventAccess()
        accessibilityGranted = AXIsProcessTrusted()
        monitor.refreshConnection()
        if !monitor.isConnected { ringController.close() }
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        openSettings(anchor: "Privacy_ListenEvent")
        statusMessage = "请在输入监控列表中允许 KeyFlow，然后返回应用。"
    }

    func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        openSettings(anchor: "Privacy_Accessibility")
        statusMessage = "请在辅助功能列表中允许 KeyFlow，然后返回应用。"
    }

    private func openSettings(anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func handleTrigger(button: TriggerButton, gesture: TriggerGesture) {
        guard isServiceEnabled, monitor.isConnected, !ringController.isVisible else { return }
        guard let rule = store.rules.first(where: {
            $0.isEnabled && $0.button == button && $0.gesture == gesture
        }) else {
            statusMessage = "收到\(button.title)\(gesture.title)，但没有启用的匹配规则"
            return
        }
        if let error = store.validationError(for: rule) {
            statusMessage = "“\(rule.name)”未执行：\(error)"
            return
        }
        statusMessage = "已触发“\(rule.name)”"
        engine.execute(rule: rule)
    }

    private func openActionsRing() {
        let rules = ringStore.availableRules(from: store.rules)
        guard !rules.isEmpty else {
            ringController.showToast("暂无可用的 Smart Action，请先创建并启用规则。", kind: .info)
            return
        }
        ringController.show(rules: rules)
    }

    private func executeFromRing(_ rule: SmartRule) {
        if let error = store.validationError(for: rule) {
            statusMessage = "“\(rule.name)”未执行：\(error)"
            return
        }
        statusMessage = "已触发“\(rule.name)”"
        engine.execute(rule: rule)
    }
}
