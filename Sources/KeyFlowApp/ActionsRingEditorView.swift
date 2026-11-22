import SwiftUI
import UniformTypeIdentifiers

private enum RingLibraryTab {
    case system
    case smartActions
}

struct ActionsRingEditorView: View {
    @ObservedObject var state: AppState
    @Binding var selectedRuleID: UUID?
    @State private var selectedSlotIndex: Int?
    @State private var libraryTab: RingLibraryTab = .system
    @State private var showMediaDrawer = true
    @State private var showOpenDrawer = true
    @State private var showNoRulesAlert = false

    private let mediaActions: [SystemActionKind] = [
        .systemVolume, .toggleMute, .volumeUp, .volumeDown,
        .resetVolume, .playPause, .nextTrack, .previousTrack
    ]
    private let openActions: [SystemActionKind] = [
        .openApplication, .openFile, .openWebpage, .finder, .systemPreferences, .openFolder
    ]

    private var ringItems: [RingItem] {
        state.ringStore.availableItems(from: state.store.rules)
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

    private var header: some View {
        HStack(spacing: 10) {
            BackHomeButton { state.currentPage = .home }
            Text("Actions Ring")
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.8)
            Text("最多 8 个操作位，支持系统操作与 Smart Action。")
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
                    items: ringItems,
                    selectedIndex: selectedSlotIndex,
                    onSelect: { _ in },
                    onClose: {},
                    onDropRule: dropHandler,
                    showEmptySlot: selectedSlotIndex == ringItems.count && ringItems.count < 8,
                    showLabels: true,
                    onSelectIndex: { selectedSlotIndex = $0 }
                )
                if ringItems.isEmpty {
                    VStack(spacing: 8) {
                        Text("还没有操作位").font(.system(size: 15, weight: .semibold))
                        Text("选择一个操作位，再从右侧添加系统操作或 Smart Action。没有操作位时，不会打开浮层。")
                            .font(.system(size: 13))
                            .foregroundStyle(KeyFlowTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .frame(width: 280)
                    }
                    .offset(y: 58)
                }
                if let index = selectedSlotIndex, ringItems.indices.contains(index) {
                    inspectCard(item: ringItems[index], index: index)
                        .frame(width: 320)
                        .position(x: 196, y: 122)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: 0xF3F3F3))
            .onDrop(of: [.text], delegate: RingSlotDropDelegate(index: selectedSlotIndex ?? ringItems.count, handler: dropHandler))

            HStack(spacing: 10) {
                Button(action: { state.ringStore.undo() }) {
                    Image(systemName: "arrow.uturn.backward").frame(width: 28, height: 28)
                }
                .buttonStyle(IconActionButtonStyle())
                .disabled(!state.ringStore.canUndo)
                .accessibilityLabel("撤销")
                Button(action: { state.ringStore.redo() }) {
                    Image(systemName: "arrow.uturn.forward").frame(width: 28, height: 28)
                }
                .buttonStyle(IconActionButtonStyle())
                .disabled(!state.ringStore.canRedo)
                .accessibilityLabel("重做")
                Text("8 个位置均可选择；拖入规则可调整顺序。")
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                Spacer()
                Button("＋ 添加操作位") {
                    selectedSlotIndex = ringItems.count
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(ringItems.count >= 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rulePanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                SegmentButton(title: "系统操作", isSelected: libraryTab == .system) { libraryTab = .system }
                SegmentButton(title: "Smart Actions", isSelected: libraryTab == .smartActions) { libraryTab = .smartActions }
            }
            .padding(3)
            .background(KeyFlowTheme.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .padding(12)

            if libraryTab == .system {
                ScrollView {
                    VStack(spacing: 8) {
                        systemDrawer(title: "媒体和音量", isExpanded: $showMediaDrawer, actions: mediaActions)
                        systemDrawer(title: "打开", isExpanded: $showOpenDrawer, actions: openActions)
                    }
                    .padding(.horizontal, 8)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach([true, false], id: \.self) { enabled in
                            let rules = state.store.rules.filter { $0.isEnabled == enabled }
                            if !rules.isEmpty {
                                Text(enabled ? "已启用 · \(rules.count)" : "已停用 · \(rules.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(KeyFlowTheme.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 10)
                                ForEach(rules) { rule in smartActionRow(rule) }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            Spacer()
            VStack(alignment: .leading, spacing: 4) {
                Button("去 Smart Actions 新建") {
                    state.store.addRule()
                    selectedRuleID = state.store.rules.last?.id
                    state.currentPage = .smartActions
                }
                .buttonStyle(.link)
                .font(.system(size: 13, weight: .semibold))
                Text("系统操作由 KeyFlow 预设；打开类操作仅设置目标，执行方式不可修改。Smart Action 仍引用原规则。")
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

    private func systemDrawer(title: String, isExpanded: Binding<Bool>, actions: [SystemActionKind]) -> some View {
        VStack(spacing: 0) {
            Button {
                isExpanded.wrappedValue.toggle()
            } label: {
                HStack {
                    Image(systemName: isExpanded.wrappedValue ? "chevron.down" : "chevron.right")
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .padding(12)
                .background(KeyFlowTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if isExpanded.wrappedValue {
                LazyVStack(spacing: 6) {
                    ForEach(actions) { action in
                        systemRow(action)
                    }
                }
                .padding(.top, 8)
            }
        }
    }

    private var addableRules: [SmartRule] {
        state.store.rules.filter { rule in
            rule.isEnabled && !ringItems.contains(where: { $0.id == RingItem.referenceID(for: rule) })
        }
    }

    private func systemRow(_ action: SystemActionKind) -> some View {
        let isInRing = !action.requiresConfiguration && ringItems.contains { $0.systemAction == action }
        return Button {
            add(RingItem.referenceID(for: action))
        } label: {
            HStack(spacing: 10) {
                ActionIconView(name: action.icon, size: 20)
                Text(action.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KeyFlowTheme.text)
                Spacer()
                if action == .systemVolume {
                    ActionIconView(name: "arrow.clockwise.circle", size: 18)
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
                if isInRing { Text("已在 Ring").tagStyle() }
            }
            .padding(10)
            .background(KeyFlowTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KeyFlowTheme.border))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(selectedSlotIndex == nil || isInRing)
        .opacity(selectedSlotIndex == nil || isInRing ? 0.4 : 1)
        .onDrag { NSItemProvider(object: RingItem.referenceID(for: action) as NSString) }
    }

    private func smartActionRow(_ rule: SmartRule) -> some View {
        let id = RingItem.referenceID(for: rule)
        let isInRing = ringItems.contains { $0.id == id }
        let disabled = selectedSlotIndex == nil || isInRing || !rule.isEnabled
        return Button {
            add(id)
        } label: {
            HStack(spacing: 10) {
                ActionIconView(name: rule.actions.first?.kind.systemImage ?? "sparkles", size: 16)
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
                if isInRing { Text("已在 Ring").tagStyle() }
                else if !rule.isEnabled { Text("启用后可添加").tagStyle() }
            }
            .padding(8)
            .background(isInRing ? KeyFlowTheme.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
        .onDrag { NSItemProvider(object: id as NSString) }
    }

    private func inspectCard(item: RingItem, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RingItemIconView(item: item, size: 20)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(KeyFlowTheme.text)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.system(size: 14, weight: .semibold))
                    Text(item.kind == .systemAction ? "系统预设操作" : item.rule?.actions.first?.kind.title ?? "多步动作")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                    Text(item.systemAction?.requiresConfiguration == true ? "在详情中设置打开目标。" : item.kind == .systemAction ? "固定执行，不允许修改。" : "引用已有 Smart Action，不另存副本。")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
            }
            HStack(spacing: 8) {
                Button("编辑") {
                    state.ringDetailItem = item
                    state.currentPage = .actionsRingDetail
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("从 Ring 移除") {
                    state.ringStore.remove(at: index, from: state.store.rules)
                    selectedSlotIndex = nil
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            if let rule = item.rule {
                Button("在 Smart Actions 中编辑") {
                    selectedRuleID = rule.id
                    state.currentPage = .smartActions
                }
                .buttonStyle(.link)
                .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(14)
        .background(KeyFlowTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(KeyFlowTheme.border))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    private func add(_ id: String) {
        guard let index = selectedSlotIndex else { return }
        if index < ringItems.count {
            state.ringStore.replace(at: index, with: id, from: state.store.rules)
        } else {
            state.ringStore.add(id, from: state.store.rules)
        }
        selectedSlotIndex = state.ringStore.availableItems(from: state.store.rules).count
    }

    private var dropHandler: @Sendable (String, Int) -> Void {
        { id, index in
            Task { @MainActor in self.performDrop(id, index) }
        }
    }

    private func performDrop(_ id: String, _ index: Int) {
        if let sourceIndex = ringItems.firstIndex(where: { $0.id == id }) {
            state.ringStore.move(from: sourceIndex, to: min(index, ringItems.count - 1), from: state.store.rules)
        } else {
            add(id)
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
