import AppKit
import SwiftUI

struct ActionEditor: View {
    @Binding var action: SmartAction
    let number: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let isRunning: Bool
    let isFailed: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    private var isCompact: Bool { action.kind == .keyboardShortcut }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("\(number)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(KeyFlowTheme.accent)
                    .clipShape(Circle())
                Image(systemName: action.kind.systemImage)
                    .foregroundStyle(KeyFlowTheme.text)
                    .frame(width: 20)
                Picker("动作类型", selection: $action.kind) {
                    ForEach(ActionKind.allCases) { kind in Text(kind.title).tag(kind) }
                }
                .labelsHidden()
                .frame(minWidth: 190, maxWidth: 220)
                if isCompact {
                    ShortcutRecorder(shortcut: $action.shortcut, compact: true)
                    Spacer()
                } else {
                    Spacer()
                }
                iconButtons
            }
            if !isCompact { actionContent }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, isCompact ? 8 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KeyFlowTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFailed ? KeyFlowTheme.error : isRunning ? KeyFlowTheme.text : KeyFlowTheme.border, lineWidth: isFailed || isRunning ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 5, y: 2)
    }

    private var iconButtons: some View {
        HStack(spacing: 2) {
            iconButton("chevron.up", help: "上移动作", action: onMoveUp).disabled(!canMoveUp)
            iconButton("chevron.down", help: "下移动作", action: onMoveDown).disabled(!canMoveDown)
            iconButton("trash", help: "删除动作", action: onDelete)
        }
    }

    @ViewBuilder
    private var actionContent: some View {
        switch action.kind {
        case .keyboardShortcut:
            ShortcutRecorder(shortcut: $action.shortcut)
        case .openApplication:
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("应用、文件或文件夹路径")
                HStack {
                    TextField("/System/Applications/Calculator.app", text: $action.target)
                        .textFieldStyle(.roundedBorder)
                    Button("选择目标") { chooseTarget() }.buttonStyle(SecondaryButtonStyle())
                }
            }
        case .openURL:
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("网址")
                TextField("https://www.example.com", text: $action.target)
                    .textFieldStyle(.roundedBorder)
            }
        case .typeText:
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("要输入的文本")
                TextEditor(text: $action.text)
                    .font(.system(size: 13))
                    .frame(minHeight: 72)
                    .scrollContentBackground(.hidden)
                    .background(KeyFlowTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(KeyFlowTheme.border))
            }
        case .runShortcut:
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("快捷指令名称")
                TextField("输入 macOS 快捷指令的完整名称", text: $action.target)
                    .textFieldStyle(.roundedBorder)
            }
        case .appleScript:
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("AppleScript")
                TextEditor(text: $action.text)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .background(KeyFlowTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(KeyFlowTheme.border))
            }
        case .wait:
            HStack(spacing: 12) {
                Text("等待时长").font(.system(size: 13))
                TextField("毫秒", value: $action.delayMilliseconds, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                Stepper("", value: $action.delayMilliseconds, in: 0...600_000, step: 50)
                Text("毫秒").foregroundStyle(KeyFlowTheme.secondaryText)
            }
        case .showActionsRing:
            InlineMessage(text: "执行此动作时，会在当前光标位置打开 Actions Ring。")
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(KeyFlowTheme.secondaryText)
    }

    private func iconButton(_ image: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: image)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(IconActionButtonStyle())
        .help(help)
        .accessibilityLabel(help)
    }

    private func chooseTarget() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        action.target = url.path
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    var compact = false
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            if !compact {
                VStack(alignment: .leading, spacing: 4) {
                    Text("快捷键")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                    shortcutLabel
                }
                Spacer()
            } else {
                shortcutLabel
            }
            Button(isRecording ? "按 Esc 取消" : shortcut == nil ? "录制快捷键" : "重新录制") {
                isRecording ? stopRecording() : startRecording()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .onDisappear(perform: stopRecording)
    }

    private var shortcutLabel: some View {
        Text(shortcut?.display ?? "尚未录制")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(shortcut == nil ? KeyFlowTheme.warning : KeyFlowTheme.text)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(KeyFlowTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(KeyFlowTheme.border))
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags
            shortcut = KeyShortcut(
                keyCode: Int(event.keyCode),
                command: flags.contains(.command),
                shift: flags.contains(.shift),
                option: flags.contains(.option),
                control: flags.contains(.control)
            )
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
