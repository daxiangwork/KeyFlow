import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum RingIconSource: String, CaseIterable, Identifiable {
    case library
    case upload

    var id: String { rawValue }
}

private let ringIconLibrary: [String] = [
    "sparkles", "command", "globe", "doc", "folder", "app",
    "square.and.arrow.up", "finder", "gearshape", "keyboard", "terminal", "clock",
    "bolt", "text.cursor", "ellipsis.message", "photo", "camera", "music.note",
    "speaker.wave.2", "speaker.slash", "playpause", "forward.end", "backward.end",
    "display", "lock", "moon", "sun.max", "wifi", "heart", "star", "magnifyingglass",
    "calendar", "list.bullet", "rectangle.grid.2x2", "circle.dotted"
]

struct ActionsRingDetailView: View {
    @ObservedObject var state: AppState
    @Binding var selectedRuleID: UUID?
    let item: RingItem
    @State private var configuration: SystemActionConfiguration
    @State private var displayName: String
    @State private var selectedIcon: String
    @State private var iconSource: RingIconSource
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
        _displayName = State(initialValue: item.title)
        _selectedIcon = State(initialValue: item.customImageData == nil ? item.icon : SystemActionKind.openApplication.icon)
        _iconSource = State(initialValue: item.customImageData == nil ? .library : .upload)
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

    private var normalizedName: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? item.title : String(name.prefix(24))
    }

    private var draftItem: RingItem {
        var draft = item
        draft.title = normalizedName
        if iconSource == .upload, let customImageData {
            draft.customImageData = customImageData
        } else {
            draft.customImageData = nil
            draft.icon = selectedIcon
        }
        return draft
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
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 10) {
                    BackHomeButton { state.currentPage = .actionsRing }
                    Text("Actions Ring 详情")
                        .font(.system(size: 28, weight: .bold))
                }

                HStack(spacing: 16) {
                    RingItemIconView(item: draftItem, size: 30)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(KeyFlowTheme.text)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 6) {
                        Text(draftItem.title)
                            .font(.system(size: 24, weight: .semibold))
                        Text(item.kind == .systemAction ? "系统预设操作 · 仅修改当前 Ring 按钮显示" : "Smart Action · 仅修改当前 Ring 按钮显示")
                            .font(.system(size: 13))
                            .foregroundStyle(KeyFlowTheme.secondaryText)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassSurface()

                appearanceEditor

                if isConfigurable {
                    targetEditor
                }

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
                }
            }
            .padding(32)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KeyFlowTheme.canvas)
    }

    private var appearanceEditor: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("按钮外观")
                    .font(.system(size: 18, weight: .semibold))
                Text("名称和图标只作用于当前 Ring 按钮，不会改变系统菜单或 Smart Action 的名称。")
                    .font(.system(size: 13))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
            }

            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 10) {
                    RingItemIconView(item: draftItem, size: 26)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(KeyFlowTheme.text)
                        .clipShape(Circle())
                    Text("Ring 按钮")
                        .font(.system(size: 11))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                }
                .frame(width: 96)

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Ring 名称")
                                .font(.system(size: 13, weight: .medium))
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
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("图标")
                            .font(.system(size: 13, weight: .medium))
                        Picker("图标来源", selection: $iconSource) {
                            Text("图标库").tag(RingIconSource.library)
                            Text("上传图片").tag(RingIconSource.upload)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 260)
                    }

                    if iconSource == .library {
                        iconLibraryGrid
                    } else {
                        uploadEditor
                    }
                }
            }

            HStack(spacing: 10) {
                Button("恢复默认显示") { resetAppearance() }
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface()
    }

    private var iconLibraryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 8), count: 8), spacing: 8) {
            ForEach(ringIconLibrary, id: \.self) { icon in
                Button {
                    selectedIcon = icon
                } label: {
                    ActionIconView(name: icon, size: 19)
                        .foregroundStyle(selectedIcon == icon ? .white : KeyFlowTheme.text)
                        .frame(width: 38, height: 38)
                        .background(selectedIcon == icon ? KeyFlowTheme.text : KeyFlowTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(selectedIcon == icon ? KeyFlowTheme.text : KeyFlowTheme.border)
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择图标 \(icon)")
            }
        }
        .frame(maxWidth: 344, alignment: .leading)
    }

    private var uploadEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button("选择图片") { chooseImage() }
                    .buttonStyle(SecondaryButtonStyle())
                if customImage != nil {
                    Button("移除图片") { clearImage() }
                        .buttonStyle(SecondaryButtonStyle())
                }
            }

            if let customImage {
                RingIconCropView(
                    image: customImage,
                    offset: $cropOffset,
                    scale: $cropScale,
                    minimumScale: minimumCropScale
                )
                HStack(spacing: 10) {
                    Text("缩放")
                        .font(.system(size: 12))
                        .foregroundStyle(KeyFlowTheme.secondaryText)
                    Slider(
                        value: Binding(
                            get: { cropScale },
                            set: { cropScale = min(max(minimumCropScale, $0), 5) }
                        ),
                        in: minimumCropScale...5
                    )
                    .frame(maxWidth: 180)
                }
                Text("拖动图片调整位置，使用滑杆或触控板捏合缩放；保存时按方形区域裁剪。")
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
            } else {
                Text("选择图片后，可在方形裁剪区中拖动和调整缩放。")
                    .font(.system(size: 12))
                    .foregroundStyle(KeyFlowTheme.secondaryText)
            }
        }
    }

    private var targetEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("打开目标")
                    .font(.system(size: 18, weight: .semibold))
                Text(configurationHelp)
                    .font(.system(size: 13))
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
        iconSource = .library
    }

    private func resetAppearance() {
        displayName = item.title
        selectedIcon = item.icon
        clearImage()
    }

    private func save() {
        if isConfigurable {
            configuration.path = configuration.path.trimmingCharacters(in: .whitespacesAndNewlines)
            state.ringStore.updateConfiguration(itemID: item.id, configuration: configuration)
        }

        var override = RingItemOverride()
        override.name = normalizedName == item.title ? nil : normalizedName
        if iconSource == .upload, customImage != nil {
            if let data = croppedImageData() {
                override.customImageData = data
            } else {
                override.customImageData = customImageData
            }
        } else if selectedIcon != item.icon {
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
