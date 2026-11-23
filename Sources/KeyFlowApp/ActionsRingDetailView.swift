import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum RingIconSource: String, CaseIterable, Identifiable {
    case system
    case tabler
    case lucide
    case heroicons
    case upload

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "系统默认"
        case .tabler: "Tabler Icons"
        case .lucide: "Lucide"
        case .heroicons: "Heroicons"
        case .upload: "上传图片"
        }
    }
}

private struct RingIconChoice: Identifiable, Hashable {
    let id: String
    let title: String
}

private func bundledIcon(_ set: String, _ name: String, _ title: String) -> RingIconChoice {
    RingIconChoice(id: "asset:\(set)/\(name)", title: title)
}

private let systemIconChoices: [RingIconChoice] = [
    RingIconChoice(id: "sparkles", title: "星光"),
    RingIconChoice(id: "command", title: "Command"),
    RingIconChoice(id: "globe", title: "网页"),
    RingIconChoice(id: "doc", title: "文件"),
    RingIconChoice(id: "folder", title: "文件夹"),
    RingIconChoice(id: "app", title: "应用"),
    RingIconChoice(id: "square.and.arrow.up", title: "打开"),
    RingIconChoice(id: "finder", title: "Finder"),
    RingIconChoice(id: "gearshape", title: "设置"),
    RingIconChoice(id: "keyboard", title: "键盘"),
    RingIconChoice(id: "terminal", title: "终端"),
    RingIconChoice(id: "clock", title: "时钟"),
    RingIconChoice(id: "bolt", title: "闪电"),
    RingIconChoice(id: "text.cursor", title: "文本"),
    RingIconChoice(id: "ellipsis.message", title: "消息"),
    RingIconChoice(id: "photo", title: "照片"),
    RingIconChoice(id: "camera", title: "相机"),
    RingIconChoice(id: "music.note", title: "音乐"),
    RingIconChoice(id: "speaker.wave.2", title: "音量"),
    RingIconChoice(id: "speaker.slash", title: "静音"),
    RingIconChoice(id: "playpause", title: "播放暂停"),
    RingIconChoice(id: "forward.end", title: "下一曲"),
    RingIconChoice(id: "backward.end", title: "上一曲"),
    RingIconChoice(id: "display", title: "显示器"),
    RingIconChoice(id: "lock", title: "锁定"),
    RingIconChoice(id: "moon", title: "月亮"),
    RingIconChoice(id: "sun.max", title: "太阳"),
    RingIconChoice(id: "wifi", title: "无线"),
    RingIconChoice(id: "heart", title: "收藏"),
    RingIconChoice(id: "star", title: "星标"),
    RingIconChoice(id: "magnifyingglass", title: "搜索"),
    RingIconChoice(id: "calendar", title: "日历"),
    RingIconChoice(id: "list.bullet", title: "列表"),
    RingIconChoice(id: "rectangle.grid.2x2", title: "网格"),
    RingIconChoice(id: "circle.dotted", title: "更多")
]

private let tablerIconChoices: [RingIconChoice] = [
    bundledIcon("tabler", "app-window", "应用窗口"),
    bundledIcon("tabler", "bolt", "闪电"),
    bundledIcon("tabler", "calendar", "日历"),
    bundledIcon("tabler", "camera", "相机"),
    bundledIcon("tabler", "circle-dotted", "更多"),
    bundledIcon("tabler", "clock", "时钟"),
    bundledIcon("tabler", "command", "Command"),
    bundledIcon("tabler", "device-desktop", "显示器"),
    bundledIcon("tabler", "file", "文件"),
    bundledIcon("tabler", "folder", "文件夹"),
    bundledIcon("tabler", "heart", "收藏"),
    bundledIcon("tabler", "keyboard", "键盘"),
    bundledIcon("tabler", "layout-grid", "网格"),
    bundledIcon("tabler", "letter-case", "文本"),
    bundledIcon("tabler", "list", "列表"),
    bundledIcon("tabler", "lock", "锁定"),
    bundledIcon("tabler", "message", "消息"),
    bundledIcon("tabler", "moon", "月亮"),
    bundledIcon("tabler", "music", "音乐"),
    bundledIcon("tabler", "photo", "照片"),
    bundledIcon("tabler", "player-pause", "暂停"),
    bundledIcon("tabler", "player-play", "播放"),
    bundledIcon("tabler", "player-skip-back", "上一曲"),
    bundledIcon("tabler", "player-skip-forward", "下一曲"),
    bundledIcon("tabler", "search", "搜索"),
    bundledIcon("tabler", "settings", "设置"),
    bundledIcon("tabler", "sparkles", "星光"),
    bundledIcon("tabler", "star", "星标"),
    bundledIcon("tabler", "sun", "太阳"),
    bundledIcon("tabler", "terminal", "终端"),
    bundledIcon("tabler", "volume", "音量"),
    bundledIcon("tabler", "volume-off", "静音"),
    bundledIcon("tabler", "wifi", "无线"),
    bundledIcon("tabler", "world", "网页")
]

private let lucideIconChoices: [RingIconChoice] = [
    bundledIcon("lucide", "app-window", "应用窗口"),
    bundledIcon("lucide", "calendar", "日历"),
    bundledIcon("lucide", "camera", "相机"),
    bundledIcon("lucide", "circle-dashed", "更多"),
    bundledIcon("lucide", "clock", "时钟"),
    bundledIcon("lucide", "command", "Command"),
    bundledIcon("lucide", "file", "文件"),
    bundledIcon("lucide", "folder", "文件夹"),
    bundledIcon("lucide", "globe", "网页"),
    bundledIcon("lucide", "heart", "收藏"),
    bundledIcon("lucide", "image", "照片"),
    bundledIcon("lucide", "keyboard", "键盘"),
    bundledIcon("lucide", "layout-grid", "网格"),
    bundledIcon("lucide", "list", "列表"),
    bundledIcon("lucide", "lock", "锁定"),
    bundledIcon("lucide", "message-square", "消息"),
    bundledIcon("lucide", "monitor", "显示器"),
    bundledIcon("lucide", "moon", "月亮"),
    bundledIcon("lucide", "file-music", "音乐"),
    bundledIcon("lucide", "pause", "暂停"),
    bundledIcon("lucide", "play", "播放"),
    bundledIcon("lucide", "search", "搜索"),
    bundledIcon("lucide", "settings", "设置"),
    bundledIcon("lucide", "skip-back", "上一曲"),
    bundledIcon("lucide", "skip-forward", "下一曲"),
    bundledIcon("lucide", "sparkles", "星光"),
    bundledIcon("lucide", "star", "星标"),
    bundledIcon("lucide", "sun", "太阳"),
    bundledIcon("lucide", "terminal", "终端"),
    bundledIcon("lucide", "type", "文本"),
    bundledIcon("lucide", "volume-2", "音量"),
    bundledIcon("lucide", "volume-x", "静音"),
    bundledIcon("lucide", "wifi", "无线"),
    bundledIcon("lucide", "zap", "闪电")
]

private let heroiconChoices: [RingIconChoice] = [
    bundledIcon("heroicons", "backward", "上一曲"),
    bundledIcon("heroicons", "bolt", "闪电"),
    bundledIcon("heroicons", "calendar", "日历"),
    bundledIcon("heroicons", "camera", "相机"),
    bundledIcon("heroicons", "chat-bubble-left-right", "消息"),
    bundledIcon("heroicons", "circle-stack", "更多"),
    bundledIcon("heroicons", "clock", "时钟"),
    bundledIcon("heroicons", "cog-6-tooth", "设置"),
    bundledIcon("heroicons", "command-line", "终端"),
    bundledIcon("heroicons", "computer-desktop", "显示器"),
    bundledIcon("heroicons", "document-text", "文件"),
    bundledIcon("heroicons", "folder", "文件夹"),
    bundledIcon("heroicons", "forward", "下一曲"),
    bundledIcon("heroicons", "globe-alt", "网页"),
    bundledIcon("heroicons", "heart", "收藏"),
    bundledIcon("heroicons", "list-bullet", "列表"),
    bundledIcon("heroicons", "magnifying-glass", "搜索"),
    bundledIcon("heroicons", "moon", "月亮"),
    bundledIcon("heroicons", "musical-note", "音乐"),
    bundledIcon("heroicons", "pause", "暂停"),
    bundledIcon("heroicons", "photo", "照片"),
    bundledIcon("heroicons", "play", "播放"),
    bundledIcon("heroicons", "sparkles", "星光"),
    bundledIcon("heroicons", "speaker-wave", "音量"),
    bundledIcon("heroicons", "speaker-x-mark", "静音"),
    bundledIcon("heroicons", "squares-2x2", "网格"),
    bundledIcon("heroicons", "star", "星标"),
    bundledIcon("heroicons", "sun", "太阳"),
    bundledIcon("heroicons", "wifi", "无线")
]

private func ringIconChoices(for source: RingIconSource) -> [RingIconChoice] {
    switch source {
    case .system: systemIconChoices
    case .tabler: tablerIconChoices
    case .lucide: lucideIconChoices
    case .heroicons: heroiconChoices
    case .upload: []
    }
}

private func ringIconSource(for icon: String) -> RingIconSource {
    if icon.hasPrefix("asset:tabler/") { return .tabler }
    if icon.hasPrefix("asset:lucide/") { return .lucide }
    if icon.hasPrefix("asset:heroicons/") { return .heroicons }
    return .system
}

private let bundledIconIndex: [RingIconSource: [RingIconChoice]] = loadBundledIconIndex()

private func loadBundledIconIndex() -> [RingIconSource: [RingIconChoice]] {
    guard let url = Bundle.main.resourceURL?.appendingPathComponent("Icons/index.txt"),
          let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
    var result: [RingIconSource: [RingIconChoice]] = [:]
    for line in text.split(separator: "\n") {
        let path = String(line)
        let id = "asset:\(path)"
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let title = name.replacingOccurrences(of: "-", with: " ")
        let source = ringIconSource(for: id)
        result[source, default: []].append(RingIconChoice(id: id, title: title))
    }
    return result.mapValues { choices in
        choices.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }
}

struct ActionsRingDetailView: View {
    @ObservedObject var state: AppState
    @Binding var selectedRuleID: UUID?
    let item: RingItem
    @State private var configuration: SystemActionConfiguration
    @State private var displayName: String
    @State private var selectedIcon: String
    @State private var iconSource: RingIconSource
    @State private var iconSearchText = ""
    @State private var customImage: NSImage?
    @State private var customImageData: Data?
    @State private var cropOffset: CGSize
    @State private var cropScale: CGFloat
    @State private var minimumCropScale: CGFloat

    init(state: AppState, selectedRuleID: Binding<UUID?>, item: RingItem) {
        self.state = state
        _selectedRuleID = selectedRuleID
        self.item = item
        _configuration = State(initialValue: item.configuration ?? SystemActionConfiguration())
        let defaultIcon = item.rule?.actions.first?.kind.systemImage ?? item.systemAction?.icon ?? item.icon
        _displayName = State(initialValue: item.title)
        _selectedIcon = State(initialValue: item.customImageData == nil ? item.icon : defaultIcon)
        _iconSource = State(initialValue: item.customImageData == nil ? ringIconSource(for: item.icon) : .upload)
        if let data = item.customImageData, let image = NSImage(data: data) {
            let minimumScale = RingIconCropView.minimumScale(for: image.size)
            _customImage = State(initialValue: image)
            _customImageData = State(initialValue: data)
            _cropOffset = State(initialValue: .zero)
            _minimumCropScale = State(initialValue: minimumScale)
            _cropScale = State(initialValue: minimumScale * 1.05)
        } else {
            _customImage = State(initialValue: nil)
            _customImageData = State(initialValue: nil)
            _cropOffset = State(initialValue: .zero)
            _minimumCropScale = State(initialValue: 1)
            _cropScale = State(initialValue: 1)
        }
    }

    private var isConfigurable: Bool {
        item.systemAction?.requiresConfiguration == true
    }

    private var defaultName: String {
        item.rule?.name ?? item.systemAction?.title ?? item.title
    }

    private var defaultIcon: String {
        item.rule?.actions.first?.kind.systemImage ?? item.systemAction?.icon ?? item.icon
    }

    private var normalizedName: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? defaultName : String(name.prefix(24))
    }

    private var draftItem: RingItem {
        var draft = item
        draft.title = normalizedName
        if iconSource == .upload, customImage != nil {
            draft.customImageData = croppedImageData() ?? customImageData
        } else {
            draft.customImageData = nil
            draft.icon = selectedIcon
        }
        return draft
    }

    private var currentIconDescription: String {
        if iconSource == .upload { return "自定义图片" }
        return iconSource.title
    }

    private var totalIconCount: Int {
        if iconSource == .system { return systemIconChoices.count }
        return bundledIconIndex[iconSource]?.count ?? 0
    }

    private var displayedIconChoices: [RingIconChoice] {
        let recommended = ringIconChoices(for: iconSource)
        let query = iconSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return recommended }
        let allChoices = iconSource == .system ? recommended : bundledIconIndex[iconSource] ?? []
        let matches = allChoices.filter { choice in
            choice.id.localizedCaseInsensitiveContains(query) || choice.title.localizedCaseInsensitiveContains(query)
        }
        return Array(matches.prefix(140))
    }

    private var iconSourceBinding: Binding<RingIconSource> {
        Binding(
            get: { iconSource },
            set: { newSource in
                iconSource = newSource
                iconSearchText = ""
                guard newSource != .upload else { return }
                let choices = ringIconChoices(for: newSource)
                if !choices.contains(where: { $0.id == selectedIcon }) {
                    selectedIcon = choices.first?.id ?? selectedIcon
                }
            }
        )
    }

    private var isValid: Bool {
        guard isConfigurable else { return true }
        let path = configuration.path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return false }
        guard item.systemAction == .openWebpage else { return true }
        guard let url = URL(string: path), let scheme = url.scheme?.lowercased() else { return false }
        return ["http", "https"].contains(scheme) && url.host != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 10) {
                    BackHomeButton { state.currentPage = .actionsRing }
                    Text("Actions Ring 详情")
                        .font(.system(size: 28, weight: .bold))
                    Spacer()
                    Text("仅修改当前 Ring 按钮")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(KeyFlowTheme.accentSoft)
                        .clipShape(Capsule())
                }

                itemSummary

                HStack(alignment: .top, spacing: 24) {
                    previewPanel

                    VStack(alignment: .leading, spacing: 20) {
                        nameEditor
                        iconEditor
                        if isConfigurable {
                            targetEditor
                        }
                        actionBar
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(32)
            .frame(maxWidth: 1080, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KeyFlowTheme.canvas)
    }

    private var itemSummary: some View {
        HStack(spacing: 16) {
            RingItemIconView(item: draftItem, size: 30)
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(KeyFlowTheme.text)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(draftItem.title)
                    .font(.system(size: 24, weight: .semibold))
                Text(item.kind == .systemAction ? "系统预设操作 · 执行方式固定" : "Smart Action · 引用现有规则")
                    .font(.system(size: 13))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var previewPanel: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                RingItemIconView(item: draftItem, size: 40)
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(KeyFlowTheme.text)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
                VStack(spacing: 5) {
                    Text(draftItem.title)
                        .font(.system(size: 18, weight: .semibold))
                        .lineLimit(1)
                    Text("当前图标 · \(currentIconDescription)")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 8)

            Divider().overlay(KeyFlowTheme.border)

            Button("恢复默认显示") { resetAppearance() }
                .buttonStyle(SecondaryButtonStyle())
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .frame(width: 280)
        .glassSurface()
    }

    private var nameEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ring 名称")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Text("\(normalizedName.count)/24")
                    .font(.system(size: 11))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
            }
            TextField("输入 Ring 按钮名称", text: Binding(
                get: { displayName },
                set: { displayName = String($0.prefix(24)) }
            ))
            .textFieldStyle(.roundedBorder)
            Text("只修改当前 Ring 按钮上的显示，不改变系统菜单或 Smart Action。")
                .font(.system(size: 12))
                .foregroundStyle(KeyFlowTheme.secondaryText)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var iconEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("图标")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Picker("图标来源", selection: iconSourceBinding) {
                    ForEach(RingIconSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 180)
            }

            if iconSource == .upload {
                uploadEditor
            } else {
                iconPickerGrid
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var iconPickerGrid: some View {
        let choices = displayedIconChoices
        let recommendedCount = ringIconChoices(for: iconSource).count
        let resultTitle = iconSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "推荐 \(recommendedCount) 个 · 共 \(totalIconCount) 个"
            : "匹配 \(choices.count) 个"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(iconSource.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(resultTitle)
                    .font(.system(size: 11))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                Spacer()
                TextField("搜索图标名称", text: $iconSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }

            if choices.isEmpty {
                Text("没有匹配的图标")
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
                    .frame(width: 368, height: 72, alignment: .center)
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 10), count: 7), spacing: 10) {
                    ForEach(choices) { choice in
                        Button {
                            selectedIcon = choice.id
                        } label: {
                            RingIconGlyphView(icon: choice.id, size: 21)
                                .foregroundStyle(selectedIcon == choice.id ? .white : KeyFlowTheme.text)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == choice.id ? KeyFlowTheme.text : KeyFlowTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedIcon == choice.id ? KeyFlowTheme.text : KeyFlowTheme.border)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 10))
                                .help(choice.title)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("选择图标 \(choice.title)")
                    }
                }
                .frame(maxWidth: 368, alignment: .leading)
            }
        }
    }

    private var uploadEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let customImage {
                HStack(alignment: .top, spacing: 20) {
                    RingIconCropView(
                        image: customImage,
                        offset: $cropOffset,
                        scale: $cropScale,
                        minimumScale: minimumCropScale
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Button("重新选择") { chooseImage() }
                                .buttonStyle(SecondaryButtonStyle())
                            Button("移除图片") { clearImage() }
                                .buttonStyle(SecondaryButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("缩放")
                                .font(.system(size: 12, weight: .medium))
                            Slider(
                                value: Binding(
                                    get: { cropScale },
                                    set: { cropScale = min(max(minimumCropScale, $0), 5) }
                                ),
                                in: minimumCropScale...5
                            )
                            .frame(width: 180)
                        }

                        Text("拖动图片调整位置，使用滑杆或触控板捏合缩放；保存时按方形区域裁剪。")
                            .font(.system(size: 12))
                            .foregroundStyle(KeyFlowTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 260, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Button("选择图片") { chooseImage() }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("支持常见图片格式。选择后可在方形区域内拖动并缩放，裁剪为 Ring 图标。")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
            }
        }
    }

    private var targetEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("打开目标")
                    .font(.system(size: 16, weight: .semibold))
                Text(configurationHelp)
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(fieldTitle)
                    .font(.system(size: 13, weight: .medium))
                HStack(spacing: 8) {
                    TextField(fieldPlaceholder, text: $configuration.path)
                        .textFieldStyle(.roundedBorder)
                    if item.systemAction != .openWebpage {
                        Button(selectionButtonTitle) { chooseTarget() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                if item.systemAction == .openWebpage && !configuration.path.isEmpty && !isValid {
                    Text("请输入以 http:// 或 https:// 开头的完整网址。")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.error)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("保存修改") { save() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!isValid)
            if let rule = item.rule {
                Button("在 Smart Actions 中编辑") {
                    selectedRuleID = rule.id
                    state.currentPage = .smartActions
                }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("在 Smart Actions 中编辑 \(rule.name)")
            }
            Spacer()
        }
    }

    private var fieldTitle: String {
        switch item.systemAction {
        case .openApplication: "应用程序路径"
        case .openFile: "文件路径"
        case .openFolder: "文件夹路径"
        case .openWebpage: "URL"
        default: "目标路径"
        }
    }

    private var fieldPlaceholder: String {
        switch item.systemAction {
        case .openApplication: "/Applications/Safari.app"
        case .openFile: "/Users/你的用户名/Documents/文件.pdf"
        case .openFolder: "/Users/你的用户名/Documents"
        case .openWebpage: "https://www.example.com"
        default: ""
        }
    }

    private var selectionButtonTitle: String {
        switch item.systemAction {
        case .openApplication: "选择应用"
        case .openFile: "选择文件"
        case .openFolder: "选择文件夹"
        default: "选择目标"
        }
    }

    private var configurationHelp: String {
        switch item.systemAction {
        case .openApplication: "选择要启动的 macOS 应用程序。"
        case .openFile: "选择要使用默认应用打开的文件。"
        case .openFolder: "选择要在 Finder 中打开的文件夹。"
        case .openWebpage: "输入要使用默认浏览器打开的完整网址。"
        default: ""
        }
    }

    private func chooseTarget() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = item.systemAction != .openFolder
        panel.canChooseDirectories = item.systemAction == .openFolder
        panel.message = configurationHelp
        switch item.systemAction {
        case .openApplication:
            panel.allowedContentTypes = [.application]
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
        case .openFile:
            panel.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        case .openFolder:
            panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        default:
            break
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        configuration.path = url.path
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image]
        panel.message = "选择要用作 Ring 图标的图片"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url),
              let image = NSImage(data: data) else { return }
        customImage = image
        customImageData = data
        minimumCropScale = RingIconCropView.minimumScale(for: image.size)
        cropScale = minimumCropScale * 1.05
        cropOffset = .zero
    }

    private func clearImage() {
        customImage = nil
        customImageData = nil
        cropOffset = .zero
        cropScale = 1
        minimumCropScale = 1
        iconSource = .system
    }

    private func resetAppearance() {
        displayName = defaultName
        selectedIcon = defaultIcon
        clearImage()
    }

    private func save() {
        if isConfigurable {
            configuration.path = configuration.path.trimmingCharacters(in: .whitespacesAndNewlines)
            state.ringStore.updateConfiguration(itemID: item.id, configuration: configuration)
        }

        var override = RingItemOverride()
        override.name = normalizedName == defaultName ? nil : normalizedName
        if iconSource == .upload, customImage != nil {
            if let data = croppedImageData() {
                override.customImageData = data
            } else {
                override.customImageData = customImageData
            }
        } else if selectedIcon != defaultIcon {
            override.icon = selectedIcon
        }
        state.ringStore.updateDisplayOverride(itemID: item.id, override: override)
        state.currentPage = .actionsRing
    }

    private func croppedImageData() -> Data? {
        guard let image = customImage else { return nil }
        let source = RingIconCropView.sourceRect(
            imageSize: image.size,
            offset: cropOffset,
            scale: cropScale
        )
        guard let cropped = RingIconCropView.crop(image, to: source) else { return nil }
        return cropped.pngData()
    }
}

private struct RingIconCropView: View {
    static let canvasSize: CGFloat = 260
    static let cropSize: CGFloat = 200

    let image: NSImage
    @Binding var offset: CGSize
    @Binding var scale: CGFloat
    let minimumScale: CGFloat
    @State private var dragStartOffset: CGSize?
    @State private var scaleStart: CGFloat?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseScale = min(size.width / image.size.width, size.height / image.size.height)
            let displayScale = baseScale * scale
            let displaySize = CGSize(width: image.size.width * displayScale, height: image.size.height * displayScale)
            let resolvedOffset = Self.clampedOffset(offset, imageSize: image.size, scale: scale)

            ZStack {
                KeyFlowTheme.accentSoft
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(resolvedOffset)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KeyFlowTheme.text, lineWidth: 2)
                    .frame(width: Self.cropSize, height: Self.cropSize)
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(KeyFlowTheme.border))
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartOffset == nil { dragStartOffset = offset }
                        offset = Self.clampedOffset(
                            CGSize(
                                width: dragStartOffset!.width + value.translation.width,
                                height: dragStartOffset!.height + value.translation.height
                            ),
                            imageSize: image.size,
                            scale: scale
                        )
                    }
                    .onEnded { _ in dragStartOffset = nil }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        if scaleStart == nil { scaleStart = scale }
                        scale = min(max(minimumScale, scaleStart! * value.magnitude), 5)
                    }
                    .onEnded { _ in
                        offset = Self.clampedOffset(offset, imageSize: image.size, scale: scale)
                        scaleStart = nil
                    }
            )
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
    }

    static func minimumScale(for imageSize: CGSize) -> CGFloat {
        let coverScale = max(cropSize / imageSize.width, cropSize / imageSize.height)
        let fitScale = min(canvasSize / imageSize.width, canvasSize / imageSize.height)
        return max(1, coverScale / fitScale)
    }

    static func clampedOffset(_ offset: CGSize, imageSize: CGSize, scale: CGFloat) -> CGSize {
        let baseScale = min(canvasSize / imageSize.width, canvasSize / imageSize.height)
        let displayScale = baseScale * scale
        let displaySize = CGSize(width: imageSize.width * displayScale, height: imageSize.height * displayScale)
        let maxX = max(0, (displaySize.width - cropSize) / 2)
        let maxY = max(0, (displaySize.height - cropSize) / 2)
        return CGSize(
            width: min(max(offset.width, -maxX), maxX),
            height: min(max(offset.height, -maxY), maxY)
        )
    }

    static func sourceRect(imageSize: CGSize, offset: CGSize, scale: CGFloat) -> CGRect {
        let baseScale = min(canvasSize / imageSize.width, canvasSize / imageSize.height)
        let displayScale = baseScale * scale
        let displaySize = CGSize(width: imageSize.width * displayScale, height: imageSize.height * displayScale)
        let resolvedOffset = clampedOffset(offset, imageSize: imageSize, scale: scale)
        let imageTopLeft = CGPoint(
            x: (canvasSize - displaySize.width) / 2 + resolvedOffset.width,
            y: (canvasSize - displaySize.height) / 2 + resolvedOffset.height
        )
        let cropTopLeft = CGPoint(
            x: (canvasSize - cropSize) / 2,
            y: (canvasSize - cropSize) / 2
        )
        let imageBottom = canvasSize - imageTopLeft.y - displaySize.height
        let cropBottom = canvasSize - cropTopLeft.y - cropSize
        return CGRect(
            x: (cropTopLeft.x - imageTopLeft.x) / displayScale,
            y: (cropBottom - imageBottom) / displayScale,
            width: cropSize / displayScale,
            height: cropSize / displayScale
        )
    }

    static func crop(_ image: NSImage, to sourceRect: CGRect) -> NSImage? {
        let outputSize = NSSize(width: 256, height: 256)
        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(outputSize.width),
            pixelsHigh: Int(outputSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
        NSColor.clear.set()
        NSRect(origin: .zero, size: outputSize).fill()
        image.draw(
            in: NSRect(origin: .zero, size: outputSize),
            from: sourceRect,
            operation: .sourceOver,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        let output = NSImage(size: outputSize)
        output.addRepresentation(representation)
        return output
    }
}

private extension NSImage {
    func pngData() -> Data? {
        guard let representation = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: representation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
