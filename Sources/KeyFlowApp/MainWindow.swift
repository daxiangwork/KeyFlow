import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MainWindow: View {
    @ObservedObject var state: AppState
    @State private var selectedRuleID: UUID?
    @State private var rulePendingDeletion: SmartRule?
    @State private var importURL: URL?
    @State private var fileError: String?

    var body: some View {
        Group {
            switch state.currentPage {
            case .home:
                HomeView(state: state)
            case .smartActions:
                SmartActionsView(
                    state: state,
                    selectedRuleID: $selectedRuleID,
                    onImport: chooseImportFile,
                    onExport: chooseExportFile,
                    onDelete: { rulePendingDeletion = $0 }
                )
            case .settings:
                SettingsView(state: state, onImport: chooseImportFile, onExport: chooseExportFile)
            case .actionsRing:
                ActionsRingEditorView(state: state, selectedRuleID: $selectedRuleID)
            case .actionsRingDetail:
                if let item = state.ringDetailItem {
                    ActionsRingDetailView(state: state, selectedRuleID: $selectedRuleID, item: item)
                }
            }
        }
        .background(KeyFlowTheme.canvas)
        .onAppear {
            selectedRuleID = state.store.rules.first?.id
            state.refreshPermissions()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            state.refreshPermissions()
        }
        .confirmationDialog(
            "删除“\(rulePendingDeletion?.name ?? "")”？",
            isPresented: Binding(get: { rulePendingDeletion != nil }, set: { if !$0 { rulePendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("删除规则", role: .destructive) { deleteSelectedRule() }
            Button("保留规则", role: .cancel) { rulePendingDeletion = nil }
        } message: {
            Text("该规则及其动作序列将被删除，而且不能恢复。其他规则不受影响。")
        }
        .confirmationDialog(
            "用导入的配置替换当前规则？",
            isPresented: Binding(get: { importURL != nil }, set: { if !$0 { importURL = nil } }),
            titleVisibility: .visible
        ) {
            Button("导入并替换") { performImport() }
            Button("取消导入", role: .cancel) { importURL = nil }
        } message: {
            Text("导入后会覆盖本机已有规则，并自动保存。建议先导出当前配置作为备份。")
        }
        .alert("无法完成文件操作", isPresented: Binding(get: { fileError != nil }, set: { if !$0 { fileError = nil } })) {
            Button("知道了") { fileError = nil }
        } message: {
            Text(fileError ?? "")
        }
    }

    private func deleteSelectedRule() {
        guard let rule = rulePendingDeletion else { return }
        let remaining = state.store.rules.filter { $0.id != rule.id }
        selectedRuleID = remaining.first?.id
        state.store.rules = remaining
        rulePendingDeletion = nil
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "选择由 KeyFlow 导出的规则配置"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importURL = url
    }

    private func chooseExportFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "KeyFlow Rules.json"
        panel.message = "保存当前规则备份"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try state.store.exportRules(to: url) } catch { fileError = error.localizedDescription }
    }

    private func performImport() {
        guard let url = importURL else { return }
        do {
            try state.store.importRules(from: url)
            selectedRuleID = state.store.rules.first?.id
        } catch {
            fileError = "无法导入：\(error.localizedDescription)。当前配置未被替换。"
        }
        importURL = nil
    }
}
