import SwiftUI

struct SmartActionsView: View {
    @ObservedObject var state: AppState
    @Binding var selectedRuleID: UUID?
    let onImport: () -> Void
    let onExport: () -> Void
    let onDelete: (SmartRule) -> Void

    var body: some View {
        VStack(spacing: 0) {
            statusBar
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    sidebar(width: sidebarWidth(for: geometry.size.width))
                    Divider().overlay(KeyFlowTheme.border)
                    editor
                }
            }
        }
        .background(KeyFlowTheme.canvas)
    }

    private var statusBar: some View {
        HStack(spacing: 14) {
            StatusItem(text: state.monitor.isConnected ? "JZ M5 已连接" : "等待 JZ M5 连接", isActive: state.monitor.isConnected)
            StatusItem(text: "输入监控\(state.inputMonitoringGranted ? "已授权" : "未授权")", isActive: state.inputMonitoringGranted, warning: !state.inputMonitoringGranted)
            StatusItem(text: "辅助功能\(state.accessibilityGranted ? "已授权" : "未授权")", isActive: state.accessibilityGranted, warning: !state.accessibilityGranted)
            if !state.inputMonitoringGranted {
                Button("授权输入监控") { state.requestInputMonitoring() }.buttonStyle(SecondaryButtonStyle())
            }
            if !state.accessibilityGranted {
                Button("授权辅助功能") { state.requestAccessibility() }.buttonStyle(SecondaryButtonStyle())
            }
            Spacer()
            Text("最近信号：\(state.monitor.lastSignal)")
                .font(.system(size: 12))
                .foregroundStyle(KeyFlowTheme.secondaryText)
                .lineLimit(1)
            SmartActionsToggle(state: state)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(KeyFlowTheme.canvas)
        .overlay(alignment: .bottom) { Divider().overlay(KeyFlowTheme.border) }
    }

    private func sidebar(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                BackHomeButton { state.currentPage = .home }
                Text("Smart Actions")
                    .font(.system(size: 17, weight: .semibold))
            }
            .padding(.bottom, 16)

            Button {
                state.store.addRule()
                selectedRuleID = state.store.rules.last?.id
            } label: {
                Text("+ 新建 Smart Action")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .frame(height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(IconActionButtonStyle())

            Text("规则")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KeyFlowTheme.secondaryText)
                .padding(.leading, 6)
                .padding(.top, 16)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(state.store.rules) { rule in
                        RuleRow(rule: rule, isSelected: selectedRuleID == rule.id) {
                            selectedRuleID = rule.id
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button("导入配置", action: onImport).buttonStyle(.link)
                    Button("导出备份", action: onExport).buttonStyle(.link)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .tint(KeyFlowTheme.text)
            .padding(.top, 12)
            .overlay(alignment: .top) { Divider().overlay(KeyFlowTheme.border) }
        }
        .padding(.horizontal, 14)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(width: width)
        .background(KeyFlowTheme.sidebar)
    }

    private var editor: some View {
        Group {
            if let selectedRule = state.store.rules.first(where: { $0.id == selectedRuleID }) {
                let ruleID = selectedRule.id
                RuleEditor(
                    rule: Binding(
                        get: { state.store.rules.first(where: { $0.id == ruleID }) ?? selectedRule },
                        set: { updatedRule in
                            guard let index = state.store.rules.firstIndex(where: { $0.id == ruleID }) else { return }
                            state.store.rules[index] = updatedRule
                        }
                    ),
                    store: state.store,
                    engine: state.engine,
                    isDeviceConnected: state.monitor.isConnected,
                    onDelete: { onDelete(selectedRule) },
                    onExport: onExport
                )
            } else {
                VStack(spacing: 12) {
                    AppIconView(size: 64)
                    Text("创建你的第一条 Smart Action")
                        .font(.system(size: 24, weight: .semibold))
                    Text("选择一个鼠标按键，再让 KeyFlow 按顺序执行多个动作。")
                        .font(.system(size: 14))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                    Button("新建 Smart Action") {
                        state.store.addRule()
                        selectedRuleID = state.store.rules.last?.id
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.top, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func sidebarWidth(for windowWidth: CGFloat) -> CGFloat {
        if windowWidth >= 1180 { return 280 }
        if windowWidth >= 980 { return 252 }
        return 232
    }
}

struct StatusItem: View {
    let text: String
    let isActive: Bool
    var warning = false

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(isActive: isActive, warning: warning)
            Text(text)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isActive ? KeyFlowTheme.text : KeyFlowTheme.secondaryText)
    }
}

struct RuleRow: View {
    let rule: SmartRule
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                MiniMouseView(button: rule.button)
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.name)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("\(rule.button.title) · \(rule.gesture.title)")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
                Spacer(minLength: 4)
                Text(rule.isEnabled ? "已启用" : "已停用")
                    .font(.system(size: 11))
                    .foregroundStyle(rule.isEnabled ? KeyFlowTheme.success : KeyFlowTheme.secondaryText)
                StatusDot(isActive: rule.isEnabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(KeyFlowTheme.text)
            .padding(10)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .background(isSelected ? KeyFlowTheme.surface : isHovering ? KeyFlowTheme.surface.opacity(0.62) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color(hex: 0xE0E0E0) : Color.clear))
            .shadow(color: .black.opacity(isSelected ? 0.05 : 0), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

struct MiniMouseView: View {
    let button: TriggerButton

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(hex: 0xF0F0F0))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(hex: 0xE0E0E0)))
                .frame(width: 16, height: 26)
                .offset(x: 2)
            RoundedRectangle(cornerRadius: 2)
                .fill(button == .middle ? KeyFlowTheme.text : Color(hex: 0xC8C8C8))
                .frame(width: 4, height: 7)
                .offset(x: 2, y: -6)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(button == .forward ? KeyFlowTheme.text : Color(hex: 0xC8C8C8))
                .frame(width: 3, height: 6)
                .offset(x: -5, y: -4)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(button == .backward ? KeyFlowTheme.text : Color(hex: 0xC8C8C8))
                .frame(width: 3, height: 6)
                .offset(x: -5, y: 3)
        }
        .frame(width: 22, height: 28)
        .accessibilityHidden(true)
    }
}
