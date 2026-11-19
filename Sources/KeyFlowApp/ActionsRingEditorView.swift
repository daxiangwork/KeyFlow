import SwiftUI
import UniformTypeIdentifiers

struct ActionsRingEditorView: View {
    @ObservedObject var state: AppState
    @Binding var selectedRuleID: UUID?
    @State private var selectedSlotID: UUID?
    @State private var replacementIndex: Int?
    @State private var searchText = ""
    @State private var showNoRulesAlert = false

    private var ringRules: [SmartRule] {
        state.ringStore.availableRules(from: state.store.rules)
    }

    private var filteredRules: [SmartRule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return state.store.rules }
        return state.store.rules.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                preview
                rulePanel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KeyFlowTheme.canvas)
        .onChange(of: ringStoreIDs) { ids in
            if let selectedSlotID, !ids.contains(selectedSlotID) { self.selectedSlotID = nil }
            replacementIndex = nil
        }
        .onAppear {
            showNoRulesAlert = !state.store.rules.contains { rule in
                rule.isEnabled && rule.actions.contains { $0.kind == .showActionsRing }
            }
        }
        .alert("还没有打开 Ring 的 Smart Action", isPresented: $showNoRulesAlert) {
            Button("去 Smart Actions 添加") { state.currentPage = .smartActions }
            Button("稍后", role: .cancel) {}
        } message: {
            Text("请在 Smart Actions 中为规则添加“打开 Actions Ring”动作，再通过该规则打开浮层。")
        }
    }

    private var ringStoreIDs: [UUID] { ringRules.map(\.id) }

    private var header: some View {
        HStack(spacing: 10) {
            BackHomeButton { state.currentPage = .home }
            Text("Actions Ring")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.8)
            Text("最多 8 个操作位，引用已有 Smart Action。")
                .font(.system(size: 13))
                .foregroundStyle(KeyFlowTheme.secondaryText)
                .padding(.leading, 12)
                .overlay(alignment: .leading) { Rectangle().fill(KeyFlowTheme.border).frame(width: 1, height: 16).offset(x: -1) }
            Spacer()
            if state.ringStore.lastSaved != nil {
                Label("已保存", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(KeyFlowTheme.success)
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .layoutPriority(1)
    }

    private var preview: some View {
        VStack(spacing: 0) {
            ZStack {
                ActionsRingView(
                    rules: ringRules,
                    selectedRuleID: selectedSlotID,
                    onSelect: { rule in
                        selectedSlotID = rule.id
                        replacementIndex = nil
                    },
                    onClose: {},
                    onDropRule: dropHandler
                )
                if ringRules.isEmpty {
                    VStack(spacing: 8) {
                        Text("还没有操作位").font(.system(size: 15, weight: .semibold))
                        Text("从右侧选择一条已启用的 Smart Action，或点击下方按钮添加。没有操作位时，不会打开浮层。")
                            .font(.system(size: 13))
                            .foregroundStyle(KeyFlowTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(width: 280)
                    }
                    .offset(y: 58)
                }
                if let selected = ringRules.first(where: { $0.id == selectedSlotID }), let index = ringRules.firstIndex(where: { $0.id == selected.id }) {
                    inspectCard(rule: selected, index: index)
                        .frame(width: 320)
                        .position(x: 196, y: 122)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: 0xF3F3F3))
            .onDrop(of: [.text], delegate: RingSlotDropDelegate(index: ringRules.count, handler: dropHandler))

            HStack(spacing: 10) {
                Button(action: { state.ringStore.undo() }) {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(IconActionButtonStyle())
                .disabled(!state.ringStore.canUndo)
                .accessibilityLabel("撤销")
                Button(action: { state.ringStore.redo() }) {
                    Image(systemName: "arrow.uturn.forward")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(IconActionButtonStyle())
                .disabled(!state.ringStore.canRedo)
                .accessibilityLabel("重做")
                Text(ringRules.isEmpty ? "没有操作位时，不会打开浮层。" : "拖动规则可调整顺序，最多 8 个操作位。")
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                Spacer()
                Menu("＋ 添加操作位") {
                    ForEach(addableRules) { rule in
                        Button(rule.name) { state.ringStore.add(rule.id, from: state.store.rules) }
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(addableRules.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                TextField("搜索 Smart Action", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(10)
            .background(KeyFlowTheme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KeyFlowTheme.border))
            .padding(12)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach([true, false], id: \.self) { enabled in
                        let rules = filteredRules.filter { $0.isEnabled == enabled }
                        if !rules.isEmpty {
                            Text(enabled ? "已启用 · \(rules.count)" : "已停用 · \(rules.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(KeyFlowTheme.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.top, 10)
                            ForEach(rules) { rule in
                                libraryRow(rule)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            VStack(alignment: .leading, spacing: 4) {
                Button("去 Smart Actions 新建") {
                    state.store.addRule()
                    selectedRuleID = state.store.rules.last?.id
                    state.currentPage = .smartActions
                }
                .buttonStyle(.link)
                .font(.system(size: 13, weight: .semibold))
                Text("操作位只引用原规则，不会另存一份。修改名称或动作后，Ring 会跟着更新。")
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .overlay(alignment: .top) { Divider().overlay(KeyFlowTheme.border) }
        }
        .frame(width: 340)
        .background(KeyFlowTheme.surface)
        .overlay(alignment: .leading) { Divider().overlay(KeyFlowTheme.border) }
    }

    private var addableRules: [SmartRule] {
        state.store.rules.filter { rule in
            rule.isEnabled && !ringRules.contains(rule) && ringRules.count < 8
        }
    }

    private func libraryRow(_ rule: SmartRule) -> some View {
        let isInRing = ringRules.contains(rule)
        return HStack(spacing: 10) {
            Image(systemName: rule.actions.first?.kind.systemImage ?? "sparkles")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(rule.isEnabled ? KeyFlowTheme.text : Color(hex: 0xC8C8C8))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(rule.actions.first?.kind.title ?? "多步动作")
                    .font(.system(size: 11))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                    .lineLimit(1)
            }
            Spacer()
            if isInRing {
                Text("已在 Ring").tagStyle()
            } else if !rule.isEnabled {
                Text("启用后可添加").tagStyle()
            } else if replacementIndex != nil {
                Text("替换").tagStyle()
            } else if ringRules.count >= 8 {
                Text("已满").tagStyle()
            }
        }
        .padding(8)
        .background(isInRing ? KeyFlowTheme.accentSoft : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture {
            guard !isInRing else { return }
            if let replacementIndex {
                state.ringStore.replace(at: replacementIndex, with: rule.id, from: state.store.rules)
                self.replacementIndex = nil
            } else if rule.isEnabled {
                state.ringStore.add(rule.id, from: state.store.rules)
            }
        }
        .onDrag { NSItemProvider(object: rule.id.uuidString as NSString) }
        .opacity(rule.isEnabled ? 1 : 0.72)
    }

    private func inspectCard(rule: SmartRule, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: rule.actions.first?.kind.systemImage ?? "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(KeyFlowTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(rule.name).font(.system(size: 14, weight: .semibold))
                    Text(rule.actions.first?.kind.title ?? "多步动作")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                    Text("引用已有 Smart Action，不另存副本。")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
            }
            HStack(spacing: 8) {
                Button(replacementIndex == index ? "选择替换规则" : "更换") {
                    replacementIndex = replacementIndex == index ? nil : index
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("从 Ring 移除") {
                    state.ringStore.remove(at: index, from: state.store.rules)
                    selectedSlotID = nil
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            Button("在 Smart Actions 中编辑") { edit(rule) }
                .buttonStyle(.link)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(14)
        .background(KeyFlowTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KeyFlowTheme.border))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    private func edit(_ rule: SmartRule) {
        selectedRuleID = rule.id
        state.currentPage = .smartActions
    }

    private var dropHandler: @Sendable (UUID, Int) -> Void {
        { id, index in
            Task { @MainActor in self.performDrop(id, index) }
        }
    }

    private func performDrop(_ id: UUID, _ index: Int) {
        if let sourceIndex = ringRules.firstIndex(where: { $0.id == id }) {
            state.ringStore.move(from: sourceIndex, to: min(index, ringRules.count - 1), from: state.store.rules)
        } else if let replacementIndex {
            state.ringStore.replace(at: replacementIndex, with: id, from: state.store.rules)
            self.replacementIndex = nil
        } else {
            state.ringStore.add(id, at: index, from: state.store.rules)
        }
    }
}

private extension Text {
    func tagStyle() -> some View {
        font(.system(size: 11, weight: .medium))
            .foregroundStyle(KeyFlowTheme.secondaryText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(KeyFlowTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
