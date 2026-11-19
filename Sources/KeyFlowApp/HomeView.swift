import SwiftUI

struct HomeView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(greeting)
                    .font(.system(size: 36, weight: .bold))
                    .tracking(-1.2)
                    .foregroundStyle(KeyFlowTheme.text)
                Spacer()
                HomeToolButton(title: "Smart Actions", assetName: "icon-smart-actions") {
                    state.currentPage = .smartActions
                }
                HomeToolButton(title: "Actions Ring", assetName: "icon-actions-ring") {
                    state.currentPage = .actionsRing
                }
                HomeToolButton(title: "设置", assetName: "icon-settings") {
                    state.currentPage = .settings
                }
            }
            .padding(.top, 18)

            GeometryReader { geometry in
                HStack(spacing: 40) {
                    Spacer(minLength: 0)
                    deviceCluster(width: imageWidth(for: geometry.size.width))
                    if state.monitor.isConnected {
                        VStack(spacing: 12) {
                            PermissionCard(
                                title: "输入监控",
                                description: state.inputMonitoringGranted ? "监听 JZ M5 的按键，不影响普通键盘。" : "授权后才能识别 JZ M5 的按键。",
                                systemImage: "keyboard",
                                isGranted: state.inputMonitoringGranted,
                                action: state.requestInputMonitoring
                            )
                            PermissionCard(
                                title: "辅助功能",
                                description: state.accessibilityGranted ? "执行快捷键、打开应用或输入文本。" : "授权后才能执行鼠标对应的自动化动作。",
                                systemImage: "accessibility",
                                isGranted: state.accessibilityGranted,
                                action: state.requestAccessibility
                            )
                        }
                        .frame(width: 320)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 56)
        .padding(.bottom, 36)
        .background(KeyFlowTheme.canvas)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 6..<12: "早上好"
        case 12..<18: "下午好"
        default: "晚上好"
        }
    }

    private func imageWidth(for availableWidth: CGFloat) -> CGFloat {
        if !state.monitor.isConnected { return min(560, availableWidth) }
        return min(500, max(300, availableWidth - 420))
    }

    private func deviceCluster(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            AssetImage(name: state.monitor.isConnected ? "jz-m5" : "jz-m5-disconnected")
                .scaledToFit()
                .frame(width: width, height: width * 826 / 1216)
                .accessibilityLabel(state.monitor.isConnected ? "JZ M5，已连接" : "JZ M5，未连接")

            HStack(spacing: 8) {
                StatusBadge(isConnected: state.monitor.isConnected)
                if state.monitor.isConnected {
                    BatteryBadge(reading: state.battery.reading)
                }
            }
            .offset(y: -18)

            if !state.monitor.isConnected {
                Text("请确认接收器已插入，并且鼠标已开机。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8A8A8A))
                    .offset(y: -8)
            }

            SmartActionsToggle(state: state)
                .font(.system(size: 14, weight: .medium))
                .padding(.top, 10)
        }
    }
}

struct HomeToolButton: View {
    let title: String
    var assetName: String?
    var systemImage: String?
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if let assetName {
                    AssetImage(name: assetName)
                } else {
                    Image(systemName: systemImage ?? "questionmark")
                        .resizable()
                }
            }
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(KeyFlowTheme.text)
            .frame(width: 44, height: 44)
            .background(isHovering ? KeyFlowTheme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .top) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(KeyFlowTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .fixedSize()
                    .offset(y: 52)
                    .opacity(isHovering ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(title)
        .zIndex(isHovering ? 2 : 0)
    }
}

struct StatusBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isConnected ? "checkmark.circle.fill" : "slash.circle")
                .foregroundStyle(isConnected ? KeyFlowTheme.success : Color(hex: 0x8A8A8A))
            Text(isConnected ? "已连接" : "未连接")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(isConnected ? KeyFlowTheme.text : Color(hex: 0x8A8A8A))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KeyFlowTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: 0xEBEBEB)))
    }
}

struct BatteryBadge: View {
    let reading: BatteryReading?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "battery.75")
            Text(reading.map { "\($0.percent)%" } ?? "--")
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(reading != nil && reading!.percent <= 20 ? KeyFlowTheme.warning : KeyFlowTheme.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(KeyFlowTheme.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color(hex: 0xEBEBEB)))
        .accessibilityLabel("电量 \(reading?.percent.description ?? "--")")
    }
}

struct PermissionCard: View {
    let title: String
    let description: String
    let systemImage: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
                    .background(Color(hex: 0xF4F4F4))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        StatusDot(isActive: isGranted, warning: !isGranted)
                        Text(isGranted ? "已授权" : "未授权")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isGranted ? KeyFlowTheme.success : KeyFlowTheme.warning)
                    }
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !isGranted {
                Button("去授权", action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .glassSurface(cornerRadius: 14)
    }
}
