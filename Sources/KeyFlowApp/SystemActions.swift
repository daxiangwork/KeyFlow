import AppKit
import Foundation

struct SystemActionConfiguration: Codable, Equatable {
    var path = ""
}

struct RingItemOverride: Codable, Equatable {
    var name: String?
    var icon: String?
    var customImageData: Data?

    var isEmpty: Bool {
        name == nil && icon == nil && customImageData == nil
    }
}

enum SystemActionKind: String, CaseIterable, Identifiable, Codable {
    case systemVolume
    case toggleMute
    case volumeUp
    case volumeDown
    case resetVolume
    case playPause
    case nextTrack
    case previousTrack
    case openApplication
    case openFile
    case openWebpage
    case finder
    case systemPreferences
    case openFolder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemVolume: "系统音量"
        case .toggleMute: "切换静音"
        case .volumeUp: "音量上升"
        case .volumeDown: "音量下降"
        case .resetVolume: "重置音量"
        case .playPause: "播放/暂停"
        case .nextTrack: "下一曲目"
        case .previousTrack: "上一曲目"
        case .openApplication: "打开应用程序"
        case .openFile: "打开文件"
        case .openWebpage: "网页"
        case .finder: "Finder"
        case .systemPreferences: "系统偏好设置"
        case .openFolder: "打开文件夹"
        }
    }

    var icon: String {
        switch self {
        case .systemVolume: "speaker.wave.2"
        case .toggleMute: "speaker.slash"
        case .volumeUp: "speaker.plus"
        case .volumeDown: "speaker.minus"
        case .resetVolume: "arrow.counterclockwise"
        case .playPause: "playpause"
        case .nextTrack: "forward.end"
        case .previousTrack: "backward.end"
        case .openApplication: "square.and.arrow.up"
        case .openFile: "doc"
        case .openWebpage: "globe"
        case .finder: "finder"
        case .systemPreferences: "gearshape"
        case .openFolder: "folder"
        }
    }

    var requiresConfiguration: Bool {
        switch self {
        case .openApplication, .openFile, .openWebpage, .openFolder: true
        default: false
        }
    }
}

enum RingItemKind {
    case smartAction
    case systemAction
}

struct RingItem: Identifiable, Equatable {
    let id: String
    let kind: RingItemKind
    var title: String
    var icon: String
    let rule: SmartRule?
    let systemAction: SystemActionKind?
    let configuration: SystemActionConfiguration?
    var customImageData: Data?

    init(rule: SmartRule) {
        self.init(
            id: "sa:\(rule.id.uuidString)",
            kind: .smartAction,
            title: rule.name,
            icon: rule.actions.first?.kind.systemImage ?? "sparkles",
            rule: rule,
            systemAction: nil,
            configuration: nil,
            customImageData: nil
        )
    }

    init(systemAction: SystemActionKind, configuration: SystemActionConfiguration? = nil, id: String? = nil) {
        let resolvedID: String
        if let id {
            resolvedID = id
        } else if systemAction.requiresConfiguration {
            resolvedID = "system:\(systemAction.rawValue):\(UUID().uuidString)"
        } else {
            resolvedID = "system:\(systemAction.rawValue)"
        }
        self.init(
            id: resolvedID,
            kind: .systemAction,
            title: systemAction.title,
            icon: systemAction.icon,
            rule: nil,
            systemAction: systemAction,
            configuration: configuration,
            customImageData: nil
        )
    }

    private init(
        id: String,
        kind: RingItemKind,
        title: String,
        icon: String,
        rule: SmartRule?,
        systemAction: SystemActionKind?,
        configuration: SystemActionConfiguration?,
        customImageData: Data?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.icon = icon
        self.rule = rule
        self.systemAction = systemAction
        self.configuration = configuration
        self.customImageData = customImageData
    }

    func applying(_ override: RingItemOverride?) -> RingItem {
        guard let override else { return self }
        return RingItem(
            id: id,
            kind: kind,
            title: override.name ?? title,
            icon: override.customImageData == nil ? override.icon ?? icon : icon,
            rule: rule,
            systemAction: systemAction,
            configuration: configuration,
            customImageData: override.customImageData ?? customImageData
        )
    }

    static func referenceID(for rule: SmartRule) -> String {
        "sa:\(rule.id.uuidString)"
    }

    static func referenceID(for action: SystemActionKind) -> String {
        action.requiresConfiguration ? "system:\(action.rawValue):\(UUID().uuidString)" : "system:\(action.rawValue)"
    }
}

@MainActor
enum SystemActionRunner {
    static func perform(_ action: SystemActionKind, configuration: SystemActionConfiguration? = nil) throws {
        switch action {
        case .systemVolume:
            guard let url = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension") else { return }
            NSWorkspace.shared.open(url)
        case .resetVolume:
            let script = NSAppleScript(source: "set volume output volume 50 without muted")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error {
                throw ActionExecutionError.actionFailed(error["NSAppleScriptErrorMessage"] as? String ?? "无法重置系统音量。")
            }
        case .toggleMute:
            try postMediaKey(7)
        case .volumeUp:
            try postMediaKey(0)
        case .volumeDown:
            try postMediaKey(1)
        case .playPause:
            try postMediaKey(16)
        case .nextTrack:
            try postMediaKey(17)
        case .previousTrack:
            try postMediaKey(18)
        case .openApplication:
            try openTarget(configuration?.path, message: "请先选择要打开的应用程序。")
        case .openFile, .openFolder:
            try openTarget(configuration?.path, message: "请先选择文件或文件夹路径。")
        case .openWebpage:
            let path = configuration?.path.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !path.isEmpty,
                  let url = URL(string: path),
                  let scheme = url.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  url.host != nil else {
                throw ActionExecutionError.invalidURL
            }
            guard NSWorkspace.shared.open(url) else {
                throw ActionExecutionError.actionFailed("无法打开网页，请检查默认浏览器。")
            }
        case .finder:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        case .systemPreferences:
            guard let url = URL(string: "x-apple.systempreferences:com.apple.preference") else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private static func openTarget(_ path: String?, message: String) throws {
        guard let path, !path.isEmpty else {
            throw ActionExecutionError.actionFailed(message)
        }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ActionExecutionError.applicationNotFound(path)
        }
        guard NSWorkspace.shared.open(url) else {
            throw ActionExecutionError.actionFailed("无法打开目标：\(path)")
        }
    }

    private static func postMediaKey(_ keyCode: Int) throws {
        for isDown in [true, false] {
            let data1 = (keyCode << 16) | (isDown ? 0xA00 : 0xB00)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            guard let cgEvent = event?.cgEvent else {
                throw ActionExecutionError.actionFailed("无法生成系统媒体控制事件。")
            }
            cgEvent.post(tap: .cghidEventTap)
        }
    }
}
