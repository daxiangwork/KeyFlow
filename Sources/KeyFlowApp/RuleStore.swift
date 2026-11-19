import Foundation

@MainActor
final class RuleStore: ObservableObject {
    @Published var rules: [SmartRule] = [] {
        didSet {
            guard !isLoading else { return }
            save()
        }
    }
    @Published private(set) var persistenceError: String?
    @Published private(set) var lastSaved: Date?

    private var isLoading = false
    private let fileManager = FileManager.default
    private let directoryURL: URL
    private let fileURL: URL

    init() {
        directoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KeyFlow", directoryHint: .isDirectory)
        fileURL = directoryURL.appending(path: "rules.json")
        load()
    }

    func addRule() {
        let usedTriggers = Set(rules.map { "\($0.button.rawValue)-\($0.gesture.rawValue)" })
        let button = TriggerButton.allCases.first { button in
            !usedTriggers.contains("\(button.rawValue)-\(TriggerGesture.singleClick.rawValue)")
        } ?? .middle
        let rule = SmartRule(
            name: "新建 Smart Action",
            button: button,
            gesture: .singleClick,
            actions: []
        )
        rules.append(rule)
    }

    func validationError(for rule: SmartRule) -> String? {
        if rule.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "请为规则命名。" }
        if rule.actions.isEmpty { return "请至少添加一个动作。" }
        let duplicate = rules.contains {
            $0.id != rule.id && $0.isEnabled && rule.isEnabled &&
            $0.button == rule.button && $0.gesture == rule.gesture
        }
        if duplicate { return "相同的按键和触发方式已被其他规则使用。请先停用或修改冲突规则。" }
        for action in rule.actions {
            switch action.kind {
            case .keyboardShortcut where action.shortcut == nil:
                return "有一个动作尚未录制快捷键。"
            case .openApplication, .openURL, .runShortcut:
                if action.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return "有一个动作尚未填写目标。"
                }
            case .typeText, .appleScript:
                if action.text.isEmpty { return "有一个动作尚未填写内容。" }
            default:
                continue
            }
        }
        return nil
    }

    func exportRules(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(rules).write(to: url, options: .atomic)
    }

    func importRules(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let imported = try JSONDecoder().decode([SmartRule].self, from: data)
        guard !imported.isEmpty else { throw RuleStoreError.emptyImport }
        rules = imported
    }

    func retrySave() {
        save()
    }

    private func load() {
        isLoading = true
        defer { isLoading = false }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                rules = [.starter]
                save()
                return
            }
            rules = try JSONDecoder().decode([SmartRule].self, from: Data(contentsOf: fileURL))
        } catch {
            let recoveryURL = directoryURL.appending(path: "rules-recovery-\(Int(Date().timeIntervalSince1970)).json")
            try? fileManager.copyItem(at: fileURL, to: recoveryURL)
            rules = [.starter]
            persistenceError = "原配置无法读取，恢复副本已保存到 \(recoveryURL.path)。修改规则前可先导出该文件。"
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rules).write(to: fileURL, options: .atomic)
            persistenceError = nil
            lastSaved = Date()
        } catch {
            persistenceError = "配置保存失败：\(error.localizedDescription)。请先导出备份，避免丢失修改。"
        }
    }
}

enum RuleStoreError: LocalizedError {
    case emptyImport

    var errorDescription: String? {
        "导入文件中没有规则。请选择由 KeyFlow 导出的配置文件。"
    }
}
