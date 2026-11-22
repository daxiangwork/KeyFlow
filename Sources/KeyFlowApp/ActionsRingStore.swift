import Foundation

struct ActionsRingConfiguration: Codable {
    var itemIDs: [String]?
    var ruleIDs: [UUID]?
    var configurations: [String: SystemActionConfiguration]?
    var overrides: [String: RingItemOverride]?
    var hasCustomized: Bool
}

@MainActor
final class ActionsRingStore: ObservableObject {
    private struct HistoryState {
        let itemIDs: [String]
        let hasCustomized: Bool
    }

    @Published private(set) var itemIDs: [String] = []
    @Published private(set) var configurations: [String: SystemActionConfiguration] = [:]
    @Published private(set) var overrides: [String: RingItemOverride] = [:]
    @Published private(set) var hasCustomized = false
    @Published private(set) var lastSaved: Date?
    @Published private(set) var errorMessage: String?

    private var undoStates: [HistoryState] = []
    private var redoStates: [HistoryState] = []
    private let fileManager = FileManager.default
    private let directoryURL: URL
    private let fileURL: URL

    init() {
        directoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "KeyFlow", directoryHint: .isDirectory)
        fileURL = directoryURL.appending(path: "actions-ring.json")
        load()
    }

    var canUndo: Bool { !undoStates.isEmpty }
    var canRedo: Bool { !redoStates.isEmpty }

    func availableItems(from rules: [SmartRule]) -> [RingItem] {
        if hasCustomized {
            return itemIDs.compactMap { id in
                if id.hasPrefix("sa:") {
                    guard let uuid = UUID(uuidString: String(id.dropFirst(3))),
                          let rule = rules.first(where: { $0.id == uuid && $0.isEnabled }) else { return nil }
                    return RingItem(rule: rule).applying(overrides[id])
                }
                if let action = systemAction(for: id) {
                    return RingItem(systemAction: action, configuration: configurations[id], id: id).applying(overrides[id])
                }
                return nil
            }
        }
        return rules.filter(\.isEnabled).prefix(8).map(RingItem.init(rule:))
    }

    func add(_ id: String, at index: Int? = nil, from rules: [SmartRule]) {
        var ids = availableItems(from: rules).map(\.id)
        guard ids.count < 8, !ids.contains(id), isValid(id, rules: rules) else { return }
        ids.insert(id, at: min(index ?? ids.count, ids.count))
        commit(ids, from: rules)
    }

    func upsert(_ id: String, at index: Int, from rules: [SmartRule]) {
        var ids = availableItems(from: rules).map(\.id)
        guard !ids.contains(id), isValid(id, rules: rules) else { return }
        if ids.indices.contains(index) {
            ids[index] = id
        } else {
            guard ids.count < 8 else { return }
            ids.insert(id, at: min(index, ids.count))
        }
        commit(ids, from: rules)
    }

    func replace(at index: Int, with id: String, from rules: [SmartRule]) {
        var ids = availableItems(from: rules).map(\.id)
        guard ids.indices.contains(index), !ids.contains(id), isValid(id, rules: rules) else { return }
        ids[index] = id
        commit(ids, from: rules)
    }

    func remove(at index: Int, from rules: [SmartRule]) {
        var ids = availableItems(from: rules).map(\.id)
        guard ids.indices.contains(index) else { return }
        ids.remove(at: index)
        commit(ids, from: rules)
    }

    func move(from sourceIndex: Int, to destinationIndex: Int, from rules: [SmartRule]) {
        var ids = availableItems(from: rules).map(\.id)
        guard ids.indices.contains(sourceIndex), ids.indices.contains(destinationIndex), sourceIndex != destinationIndex else { return }
        let id = ids.remove(at: sourceIndex)
        ids.insert(id, at: destinationIndex)
        commit(ids, from: rules)
    }

    func updateConfiguration(itemID: String, configuration: SystemActionConfiguration) {
        guard systemAction(for: itemID)?.requiresConfiguration == true else { return }
        configurations[itemID] = configuration
        save()
    }

    func updateDisplayOverride(itemID: String, override: RingItemOverride) {
        if override.isEmpty {
            overrides.removeValue(forKey: itemID)
        } else {
            overrides[itemID] = override
        }
        save()
    }

    func undo() {
        guard let previous = undoStates.popLast() else { return }
        redoStates.append(HistoryState(itemIDs: itemIDs, hasCustomized: hasCustomized))
        apply(previous)
    }

    func redo() {
        guard let next = redoStates.popLast() else { return }
        undoStates.append(HistoryState(itemIDs: itemIDs, hasCustomized: hasCustomized))
        apply(next)
    }

    private func systemAction(for id: String) -> SystemActionKind? {
        guard id.hasPrefix("system:") else { return nil }
        let reference = id.dropFirst(7)
        let rawValue = reference.split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
        return SystemActionKind(rawValue: rawValue)
    }

    private func isValid(_ id: String, rules: [SmartRule]) -> Bool {
        if id.hasPrefix("system:") {
            return systemAction(for: id) != nil
        }
        guard id.hasPrefix("sa:"), let uuid = UUID(uuidString: String(id.dropFirst(3))) else { return false }
        return rules.contains { $0.id == uuid && $0.isEnabled }
    }

    private func commit(_ ids: [String], from rules: [SmartRule]) {
        undoStates.append(HistoryState(itemIDs: availableItems(from: rules).map(\.id), hasCustomized: hasCustomized))
        redoStates.removeAll()
        itemIDs = ids
        hasCustomized = true
        save()
    }

    private func apply(_ state: HistoryState) {
        itemIDs = state.itemIDs
        hasCustomized = state.hasCustomized
        save()
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let configuration = try JSONDecoder().decode(ActionsRingConfiguration.self, from: Data(contentsOf: fileURL))
            if let itemIDs = configuration.itemIDs {
                self.itemIDs = itemIDs
            } else if let ruleIDs = configuration.ruleIDs {
                itemIDs = ruleIDs.map { "sa:\($0.uuidString)" }
            }
            configurations = configuration.configurations ?? [:]
            overrides = configuration.overrides ?? [:]
            hasCustomized = configuration.hasCustomized
        } catch {
            errorMessage = "Actions Ring 配置无法读取，已保留原文件。请重新调整操作位。"
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let configuration = ActionsRingConfiguration(
                itemIDs: itemIDs,
                ruleIDs: nil,
                configurations: configurations,
                overrides: overrides,
                hasCustomized: hasCustomized
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(configuration).write(to: fileURL, options: .atomic)
            lastSaved = Date()
            errorMessage = nil
        } catch {
            errorMessage = "Actions Ring 保存失败：\(error.localizedDescription)"
        }
    }
}
