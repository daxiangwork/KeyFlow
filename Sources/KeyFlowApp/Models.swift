import Foundation

enum TriggerButton: String, Codable, CaseIterable, Identifiable {
    case middle
    case forward
    case backward

    var id: String { rawValue }

    var title: String {
        switch self {
        case .middle: "中键"
        case .forward: "前进侧键"
        case .backward: "后退侧键"
        }
    }
}

enum TriggerGesture: String, Codable, CaseIterable, Identifiable {
    case singleClick
    case doubleClick
    case longPress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singleClick: "单击"
        case .doubleClick: "双击"
        case .longPress: "长按"
        }
    }
}

struct KeyShortcut: Codable, Equatable, Hashable {
    var keyCode: Int
    var command = false
    var shift = false
    var option = false
    var control = false

    var display: String {
        var parts: [String] = []
        if control { parts.append("Control") }
        if option { parts.append("Option") }
        if shift { parts.append("Shift") }
        if command { parts.append("Command") }
        parts.append(Self.keyNames[keyCode] ?? "键码 \(keyCode)")
        return parts.joined(separator: " + ")
    }

    private static let keyNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
        44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
        50: "`", 51: "Delete", 53: "Escape", 96: "F5", 97: "F7", 98: "F3",
        99: "F8", 100: "F9", 101: "F9", 103: "F11", 105: "F13", 107: "F14",
        109: "F10", 111: "F12", 113: "F15", 118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑", 160: "调度中心"
    ]
}

enum ActionKind: String, Codable, CaseIterable, Identifiable {
    case keyboardShortcut
    case openApplication
    case openURL
    case typeText
    case runShortcut
    case appleScript
    case wait
    case showActionsRing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboardShortcut: "键盘快捷键"
        case .openApplication: "打开应用或文件"
        case .openURL: "打开网址"
        case .typeText: "输入文本"
        case .runShortcut: "运行快捷指令"
        case .appleScript: "执行 AppleScript"
        case .wait: "等待"
        case .showActionsRing: "打开 Actions Ring"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboardShortcut: "keyboard"
        case .openApplication: "square.grid.2x2"
        case .openURL: "globe"
        case .typeText: "text.cursor"
        case .runShortcut: "bolt"
        case .appleScript: "terminal"
        case .wait: "clock"
        case .showActionsRing: "circle.dotted"
        }
    }
}

struct SmartAction: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ActionKind
    var shortcut: KeyShortcut?
    var target = ""
    var text = ""
    var delayMilliseconds = 100

    init(id: UUID = UUID(), kind: ActionKind) {
        self.id = id
        self.kind = kind
    }

    static func openCalculator() -> SmartAction {
        var action = SmartAction(kind: .openApplication)
        action.target = "/System/Applications/Calculator.app"
        return action
    }

    var summary: String {
        switch kind {
        case .keyboardShortcut: shortcut?.display ?? "尚未录制快捷键"
        case .openApplication: target.isEmpty ? "尚未选择应用" : URL(fileURLWithPath: target).deletingPathExtension().lastPathComponent
        case .openURL: target.isEmpty ? "尚未填写网址" : target
        case .typeText: text.isEmpty ? "尚未填写文本" : text
        case .runShortcut: target.isEmpty ? "尚未填写快捷指令名称" : target
        case .appleScript: text.isEmpty ? "尚未填写脚本" : text
        case .wait: "\(delayMilliseconds) 毫秒"
        case .showActionsRing: "打开 Actions Ring"
        }
    }
}

struct SmartRule: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var button: TriggerButton
    var gesture: TriggerGesture
    var isEnabled = true
    var actions: [SmartAction]

    init(id: UUID = UUID(), name: String, button: TriggerButton, gesture: TriggerGesture, actions: [SmartAction]) {
        self.id = id
        self.name = name
        self.button = button
        self.gesture = gesture
        self.actions = actions
    }

    static var starter: SmartRule {
        SmartRule(name: "打开计算器", button: .middle, gesture: .singleClick, actions: [.openCalculator()])
    }
}
