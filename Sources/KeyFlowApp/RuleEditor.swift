import SwiftUI

struct RuleEditor: View {
    @Binding var rule: SmartRule
    @ObservedObject var store: RuleStore
    @ObservedObject var engine: ActionEngine
    let isDeviceConnected: Bool
    let onDelete: () -> Void
    let onExport: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            TextField("规则名称", text: $rule.name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 28, weight: .semibold))
                                .tracking(-0.8)
                                .foregroundStyle(KeyFlowTheme.text)
                            Label(saveText, systemImage: store.persistenceError == nil ? "checkmark.circle" : "exclamationmark.circle")
                                .font(.system(size: 12))
                                .foregroundStyle(store.persistenceError == nil ? KeyFlowTheme.success : KeyFlowTheme.error)
                        }
                        Spacer()
                        HStack(spacing: 12) {
                            Toggle("启用规则", isOn: $rule.isEnabled).tint(KeyFlowTheme.accent)
                            Button(engine.runningRuleID == rule.id ? "正在执行…" : "运行测试") {
                                engine.execute(rule: rule)
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(store.validationError(for: rule) != nil || engine.runningRuleID != nil)
                        }
                        .padding(.top, 6)
                    }

                    if let error = store.validationError(for: rule) {
                        InlineMessage(text: error, isWarning: true)
                    }
                    if let error = store.persistenceError {
                        VStack(alignment: .leading, spacing: 8) {
                            InlineMessage(text: error, isError: true)
                            HStack {
                                Button("导出备份", action: onExport).buttonStyle(SecondaryButtonStyle())
                                Button("重试保存") { store.retrySave() }.buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    if !isDeviceConnected {
                        InlineMessage(text: "JZ M5 已断开。规则配置已保留，重新连接后会继续监听。", isWarning: true)
                    }

                    sectionHeader("当鼠标这样做", detail: "每个按键与触发方式只能对应一条启用规则")
                    triggerPanel

                    HStack(alignment: .bottom) {
                        sectionHeader("按顺序执行", detail: "动作会从第一步依次运行到最后一步")
                        Spacer()
                        Menu {
                            ForEach(ActionKind.allCases) { kind in
                                Button(kind.title) { rule.actions.append(SmartAction(kind: kind)) }
                            }
                        } label: {
                            Label("添加动作", systemImage: "plus")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }

                    if rule.actions.isEmpty {
                        VStack(spacing: 8) {
                            Text("还没有动作").font(.system(size: 16, weight: .medium))
                            Text("添加一个快捷键、打开应用或其他动作。")
                                .font(.system(size: 13))
                                .foregroundStyle(KeyFlowTheme.secondaryText)
                            Button("添加第一个动作") { rule.actions.append(SmartAction(kind: .keyboardShortcut)) }
                                .buttonStyle(SecondaryButtonStyle())
                                .padding(.top, 6)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                        .glassSurface()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach($rule.actions) { $action in
                                ActionEditor(
                                    action: $action,
                                    number: (rule.actions.firstIndex(of: action) ?? 0) + 1,
                                    canMoveUp: rule.actions.first != action,
                                    canMoveDown: rule.actions.last != action,
                                    isRunning: engine.activeActionID == action.id,
                                    isFailed: engine.failedActionID == action.id,
                                    onMoveUp: { move(action, offset: -1) },
                                    onMoveDown: { move(action, offset: 1) },
                                    onDelete: { rule.actions.removeAll { $0.id == action.id } }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)
                .padding(.bottom, 12)
            }

            HStack(spacing: 8) {
                Image(systemName: engine.failedActionID == nil ? "checkmark.circle" : "exclamationmark.circle")
                Text(engine.lastResult)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("删除规则", role: .destructive, action: onDelete)
                    .buttonStyle(.borderless)
                    .foregroundStyle(KeyFlowTheme.error)
            }
            .font(.system(size: 12))
            .foregroundStyle(engine.failedActionID == nil ? KeyFlowTheme.success : KeyFlowTheme.error)
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(KeyFlowTheme.canvas)
            .overlay(alignment: .top) { Divider().overlay(KeyFlowTheme.border) }
        }
    }

    private var saveText: String {
        if store.persistenceError != nil { return "保存失败，请先导出备份" }
        return store.lastSaved == nil ? "修改会自动保存到本机" : "已自动保存到本机 · 刚刚"
    }

    private var triggerPanel: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                MouseTriggerDiagram(button: $rule.button)
                    .frame(width: 112)
                triggerFields
            }
            VStack(spacing: 16) {
                MouseTriggerDiagram(button: $rule.button)
                triggerFields
            }
        }
        .padding(16)
        .glassSurface()
    }

    private var triggerFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("鼠标按键")
                HStack(spacing: 2) {
                    ForEach(TriggerButton.allCases) { button in
                        SegmentButton(title: button.title, isSelected: rule.button == button) { rule.button = button }
                    }
                }
                .padding(3)
                .background(KeyFlowTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("触发方式")
                HStack(spacing: 2) {
                    ForEach(TriggerGesture.allCases) { gesture in
                        SegmentButton(title: gesture.title, isSelected: rule.gesture == gesture) { rule.gesture = gesture }
                    }
                }
                .padding(3)
                .background(KeyFlowTheme.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 18, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(KeyFlowTheme.secondaryText)
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(KeyFlowTheme.secondaryText)
    }

    private func move(_ action: SmartAction, offset: Int) {
        guard let index = rule.actions.firstIndex(of: action) else { return }
        let destination = index + offset
        guard rule.actions.indices.contains(destination) else { return }
        rule.actions.move(fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? destination + 1 : destination)
    }
}

struct SegmentButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? KeyFlowTheme.text : KeyFlowTheme.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isSelected ? KeyFlowTheme.surface : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 2, y: 1)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MouseTriggerDiagram: View {
    @Binding var button: TriggerButton

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38)
                .fill(Color(hex: 0xF5F5F5))
                .overlay(RoundedRectangle(cornerRadius: 38).stroke(KeyFlowTheme.border))
                .frame(width: 100, height: 160)
            Path { path in
                path.move(to: CGPoint(x: 50, y: 10))
                path.addLine(to: CGPoint(x: 50, y: 72))
                path.move(to: CGPoint(x: 8, y: 72))
                path.addLine(to: CGPoint(x: 92, y: 72))
            }
            .stroke(Color(hex: 0xE6E6E6), lineWidth: 1.5)
            .frame(width: 100, height: 160)
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0xEEEEEE))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(KeyFlowTheme.border))
                .frame(width: 16, height: 8)
                .offset(y: -60)
            diagramButton(.middle, width: 18, height: 34, x: 0, y: -38)
            diagramButton(.backward, width: 14, height: 26, x: -48, y: 28)
            diagramButton(.forward, width: 14, height: 26, x: -48, y: -2)
        }
        .frame(width: 112, height: 172)
    }

    private func diagramButton(_ target: TriggerButton, width: CGFloat, height: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Button { button = target } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(button == target ? KeyFlowTheme.text : Color(hex: 0xD5D5D5))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(button == target ? .black : Color(hex: 0xC4C4C4)))
                .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .offset(x: x, y: y)
        .accessibilityLabel("选择\(target.title)")
    }
}
