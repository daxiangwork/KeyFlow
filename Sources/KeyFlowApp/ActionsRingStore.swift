import Foundation

struct ActionsRingConfiguration: Codable {
    var ruleIDs: [UUID]
    var hasCustomized: Bool
}

@MainActor
final class ActionsRingStore: ObservableObject {
    private struct HistoryState {
        let ruleIDs: [UUID]
        let hasCustomized: Bool
    }

    @Published private(set) var ruleIDs: [UUID] = []
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

    func availableRules(from rules: [SmartRule]) -> [SmartRule] {
        if hasCustomized {
            return ruleIDs.compactMap { id in
                rules.first { $0.id == id && $0.isEnabled }
            }
        }
        return Array(rules.filter(\.isEnabled).prefix(8))
    }

    func conflictRule(from rules: [SmartRule]) -> SmartRule? {
        rules.first { $0.isEnabled && $0.button == .middle && $0.gesture == .longPress }
    }

    func add(_ id: UUID, at index: Int? = nil, from rules: [SmartRule]) {
        var ids = availableRules(from: rules).map(\.id)
        guard ids.count < 8, !ids.contains(id), rules.contains(where: { $0.id == id && $0.isEnabled }) else { return }
        ids.insert(id, at: min(index ?? ids.count, ids.count))
        commit(ids, from: rules)
    }

    func replace(at index: Int, with id: UUID, from rules: [SmartRule]) {
        var ids = availableRules(from: rules).map(\.id)
        guard ids.indices.contains(index), !ids.contains(id), rules.contains(where: { $0.id == id && $0.isEnabled }) else { return }
        ids[index] = id
        commit(ids, from: rules)
    }

    func remove(at index: Int, from rules: [SmartRule]) {
        var ids = availableRules(from: rules).map(\.id)
        guard ids.indices.contains(index) else { return }
        ids.remove(at: index)
        commit(ids, from: rules)
    }

    func move(from sourceIndex: Int, to destinationIndex: Int, from rules: [SmartRule]) {
        var ids = availableRules(from: rules).map(\.id)
        guard ids.indices.contains(sourceIndex), ids.indices.contains(destinationIndex), sourceIndex != destinationIndex else { return }
        let id = ids.remove(at: sourceIndex)
        ids.insert(id, at: destinationIndex)
        commit(ids, from: rules)
    }

    func undo() {
        guard let previous = undoStates.popLast() else { return }
        redoStates.append(HistoryState(ruleIDs: ruleIDs, hasCustomized: hasCustomized))
        apply(previous)
    }

    func redo() {
        guard let next = redoStates.popLast() else { return }
        undoStates.append(HistoryState(ruleIDs: ruleIDs, hasCustomized: hasCustomized))
        apply(next)
    }

    private func commit(_ ids: [UUID], from rules: [SmartRule]) {
        undoStates.append(HistoryState(ruleIDs: availableRules(from: rules).map(\.id), hasCustomized: hasCustomized))
        redoStates.removeAll()
        ruleIDs = ids
        hasCustomized = true
        save()
    }

    private func apply(_ state: HistoryState) {
        ruleIDs = state.ruleIDs
        hasCustomized = state.hasCustomized
        save()
    }

    private func load() {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        do {
            let configuration = try JSONDecoder().decode(ActionsRingConfiguration.self, from: Data(contentsOf: fileURL))
            ruleIDs = configuration.ruleIDs
            hasCustomized = configuration.hasCustomized
        } catch {
            errorMessage = "Actions Ring 配置无法读取，已保留原文件。请重新调整操作位。"
        }
    }

    private func save() {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let configuration = ActionsRingConfiguration(ruleIDs: ruleIDs, hasCustomized: hasCustomized)
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
