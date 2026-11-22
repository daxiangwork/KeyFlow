import AppKit
import CoreGraphics
import Foundation

enum ActionExecutionError: LocalizedError {
    case invalidShortcut
    case applicationNotFound(String)
    case invalidURL
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidShortcut: "请先录制一个有效的键盘快捷键。"
        case .applicationNotFound(let path): "找不到目标：\(path)。请重新选择应用或文件。"
        case .invalidURL: "网址无效。请输入完整的 http:// 或 https:// 地址。"
        case .actionFailed(let message): message
        }
    }
}

@MainActor
final class ActionEngine: ObservableObject {
    @Published private(set) var runningRuleID: UUID?
    @Published private(set) var activeActionID: UUID?
    @Published private(set) var failedActionID: UUID?
    @Published private(set) var lastResult = "尚未执行动作"

    private var tasks: [UUID: Task<Void, Never>] = [:]
    var showActionsRing: (() -> Void)?

    func execute(rule: SmartRule, completion: ((Result<String, Error>) -> Void)? = nil) {
        tasks[rule.id]?.cancel()
        let actions = rule.actions
        tasks[rule.id] = Task { @MainActor [weak self] in
            guard let self else { return }
            self.runningRuleID = rule.id
            self.failedActionID = nil
            self.activeActionID = nil
            let result: Result<String, Error>
            do {
                for (index, action) in actions.enumerated() {
                    try Task.checkCancellation()
                    self.activeActionID = action.id
                    self.lastResult = "正在执行“\(rule.name)” · 第 \(index + 1)/\(actions.count) 步"
                    try await self.perform(action)
                }
                self.lastResult = "“\(rule.name)”执行成功，\(actions.count) 个动作已按顺序执行。"
                result = .success(self.lastResult)
            } catch is CancellationError {
                self.lastResult = "已取消“\(rule.name)”"
                result = .failure(ActionExecutionError.actionFailed(self.lastResult))
            } catch {
                self.failedActionID = self.activeActionID
                self.lastResult = "“\(rule.name)”失败：\(error.localizedDescription)"
                result = .failure(error)
            }
            self.activeActionID = nil
            self.runningRuleID = nil
            self.tasks.removeValue(forKey: rule.id)
            completion?(result)
        }
    }

    func cancel(ruleID: UUID) {
        tasks[ruleID]?.cancel()
    }

    func recordResult(_ text: String) {
        lastResult = text
    }

    private func perform(_ action: SmartAction) async throws {
        switch action.kind {
        case .keyboardShortcut:
            try performShortcut(action.shortcut)
        case .openApplication:
            try await openApplication(action.target)
        case .openURL:
            try await openURL(action.target)
        case .typeText:
            try typeText(action.text)
        case .runShortcut:
            guard !action.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ActionExecutionError.actionFailed("请填写要运行的快捷指令名称。")
            }
            try await runProcess(executable: "/usr/bin/shortcuts", arguments: ["run", action.target])
        case .appleScript:
            guard !action.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ActionExecutionError.actionFailed("请填写要执行的 AppleScript。")
            }
            try await runProcess(executable: "/usr/bin/osascript", arguments: ["-e", action.text])
        case .wait:
            let milliseconds = min(max(action.delayMilliseconds, 0), 600_000)
            try await Task.sleep(for: .milliseconds(milliseconds))
        case .showActionsRing:
            showActionsRing?()
        }
    }

    private func performShortcut(_ shortcut: KeyShortcut?) throws {
        guard let shortcut, (0...1024).contains(shortcut.keyCode) else {
            throw ActionExecutionError.invalidShortcut
        }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.keyCode), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(shortcut.keyCode), keyDown: false) else {
            throw ActionExecutionError.actionFailed("无法生成键盘事件。请检查辅助功能权限。")
        }
        var flags: CGEventFlags = []
        if shortcut.command { flags.insert(.maskCommand) }
        if shortcut.shift { flags.insert(.maskShift) }
        if shortcut.option { flags.insert(.maskAlternate) }
        if shortcut.control { flags.insert(.maskControl) }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func openApplication(_ path: String) async throws {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            throw ActionExecutionError.applicationNotFound(path)
        }
        let url = URL(fileURLWithPath: path)
        if url.pathExtension != "app" {
            guard NSWorkspace.shared.open(url) else {
                throw ActionExecutionError.actionFailed("无法打开文件或文件夹。请重新选择目标。")
            }
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    private func openURL(_ string: String) async throws {
        let normalized = string.hasPrefix("http://") || string.hasPrefix("https://") ? string : "https://\(string)"
        guard let url = URL(string: normalized), let scheme = url.scheme, ["http", "https"].contains(scheme) else {
            throw ActionExecutionError.invalidURL
        }
        guard NSWorkspace.shared.open(url) else {
            throw ActionExecutionError.actionFailed("无法打开网址。请检查默认浏览器是否可用。")
        }
    }

    private func typeText(_ text: String) throws {
        guard !text.isEmpty else { throw ActionExecutionError.actionFailed("请输入要输入的文本。") }
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw ActionExecutionError.actionFailed("无法生成文本输入事件。请检查辅助功能权限。")
        }
        let characters = Array(text.utf16)
        characters.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: buffer.baseAddress)
        }
        down.post(tap: .cgSessionEventTap)
        up.post(tap: .cgSessionEventTap)
    }

    private func runProcess(executable: String, arguments: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                let process = Process()
                let output = Pipe()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                process.standardOutput = output
                process.standardError = output
                do {
                    try process.run()
                    process.waitUntilExit()
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    let message = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if process.terminationStatus == 0 {
                        continuation.resume()
                    } else {
                        continuation.resume(throwing: ActionExecutionError.actionFailed(
                            message.isEmpty ? "动作执行失败，退出码 \(process.terminationStatus)。" : message
                        ))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
