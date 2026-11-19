import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    BackHomeButton { state.currentPage = .home }
                    Text("设置")
                        .font(.system(size: 28, weight: .bold))
                        .tracking(-1)
                }
                .padding(.bottom, 28)

                VStack(spacing: 0) {
                    SettingsPermissionRow(
                        title: "输入监控",
                        hint: "用于监听 JZ M5 的按键。不会拦截普通键盘的复制和粘贴。",
                        isGranted: state.inputMonitoringGranted,
                        action: state.requestInputMonitoring
                    )
                    SettingsDivider()
                    SettingsPermissionRow(
                        title: "辅助功能",
                        hint: "执行快捷键、打开应用或输入文本。",
                        isGranted: state.accessibilityGranted,
                        action: state.requestAccessibility
                    )
                    SettingsDivider()
                    HStack(spacing: 16) {
                        SettingsText(title: "启用 Smart Actions", hint: "关闭后，规则不会被鼠标按键触发。")
                        Spacer()
                        SmartActionsToggle(state: state)
                            .labelsHidden()
                    }
                    .padding(20)
                    SettingsDivider()
                    SettingsActionRow(title: "导入配置", hint: "用备份文件替换本机规则，导入前建议先导出。", button: "导入", action: onImport)
                    SettingsDivider()
                    SettingsActionRow(title: "导出备份", hint: "把当前规则保存为本地文件。", button: "导出", action: onExport)
                }
                .frame(maxWidth: 720)
                .background(KeyFlowTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: 0xEBEBEB)))

                Text("没有账号和云同步。授权项缺失时，可从首页进入设置，或在 Smart Actions 页顶栏完成授权。")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hex: 0x8A8A8A))
                    .padding(.top, 16)
                    .frame(maxWidth: 720, alignment: .leading)
            }
            .padding(.horizontal, 56)
            .padding(.top, 20)
            .padding(.bottom, 48)
        }
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeyFlowTheme.canvas)
    }
}

struct BackHomeButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(isHovering ? KeyFlowTheme.accentSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("返回首页")
    }
}

struct SettingsText: View {
    let title: String
    let hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(KeyFlowTheme.text)
            Text(hint)
                .font(.system(size: 13))
                .foregroundStyle(KeyFlowTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider().overlay(Color(hex: 0xF2F2F2))
    }
}

struct SettingsPermissionRow: View {
    let title: String
    let hint: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            SettingsText(title: title, hint: hint)
            Spacer()
            if !isGranted {
                Button("去授权", action: action).buttonStyle(SecondaryButtonStyle())
            }
            Text(isGranted ? "已授权" : "未授权")
                .font(.system(size: 13))
                .foregroundStyle(isGranted ? KeyFlowTheme.success : KeyFlowTheme.warning)
            StatusDot(isActive: isGranted, warning: !isGranted)
        }
        .padding(20)
    }
}

struct SettingsActionRow: View {
    let title: String
    let hint: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            SettingsText(title: title, hint: hint)
            Spacer()
            Button(button, action: action).buttonStyle(SecondaryButtonStyle())
        }
        .padding(20)
    }
}
