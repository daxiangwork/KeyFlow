import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ActionsRingView: View {
    let items: [RingItem]
    var selectedIndex: Int?
    let onSelect: (RingItem) -> Void
    let onClose: () -> Void
    var onDropRule: (@Sendable (String, Int) -> Void)? = nil
    var animateAppearance = false
    var showEmptySlot = false
    var showLabels = false
    var onSelectIndex: ((Int) -> Void)? = nil
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            let count = showEmptySlot && items.count < 8 ? items.count + 1 : items.count
            ForEach(0..<count, id: \.self) { index in
                let item = items.indices.contains(index) ? items[index] : nil
                let angle = Double(index) * 360 / Double(count)
                let radians = (angle - 90) * .pi / 180
                let x = 300 + 86 * cos(radians)
                let y = 300 + 86 * sin(radians)
                RingSlot(
                    item: item,
                    isSelected: selectedIndex == index,
                    labelAngle: showLabels ? angle : nil,
                    action: {
                        if let onSelectIndex {
                            onSelectIndex(index)
                        } else if let item {
                            onSelect(item)
                        }
                    }
                )
                .position(x: isExpanded ? x : 300, y: isExpanded ? y : 300)
                .scaleEffect(isExpanded ? 1 : 0.72)
                .opacity(isExpanded ? 1 : 0)
                .zIndex(Double(index) + 1)
                .onDrop(of: [.text], delegate: RingSlotDropDelegate(index: index, handler: onDropRule))
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x3A3A3A))
                    .frame(width: 36, height: 36)
                    .background(Color(hex: 0xE8E8E8))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.black.opacity(0.08)))
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .position(x: 300, y: 300)
            .scaleEffect(isExpanded ? 1 : 0.85)
            .opacity(isExpanded ? 1 : 0)
            .zIndex(100)
            .accessibilityLabel("关闭")
        }
        .frame(width: 600, height: 600)
        .accessibilityElement(children: .contain)
        .onAppear {
            if animateAppearance {
                withAnimation(.spring(response: 0.18, dampingFraction: 0.72)) {
                    isExpanded = true
                }
            } else {
                isExpanded = true
            }
        }
    }
}

private enum RingLabelMetrics {
    static let fontSize: CGFloat = 13
    static let horizontalPadding: CGFloat = 12
    static let verticalPadding: CGFloat = 7
    static let height: CGFloat = 30
    static let maxWidth: CGFloat = 160
    static let minimumWidth: CGFloat = 52
    static let buttonRadius: CGFloat = 24
    static let gap: CGFloat = 12

    static func width(for title: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return min(maxWidth, max(minimumWidth, ceil(textWidth) + horizontalPadding * 2))
    }

    static func offset(angle: Double, size: CGSize) -> CGSize {
        let radians = (angle - 90) * .pi / 180
        let direction = CGSize(width: cos(radians), height: sin(radians))
        let halfExtent = (abs(direction.width) * size.width + abs(direction.height) * size.height) / 2
        let distance = buttonRadius + gap + halfExtent
        return CGSize(width: direction.width * distance, height: direction.height * distance)
    }
}

private struct RingSlot: View {
    let item: RingItem?
    let isSelected: Bool
    let labelAngle: Double?
    let action: () -> Void
    @State private var isHovering = false

    private var labelWidth: CGFloat {
        guard let item else { return 0 }
        return RingLabelMetrics.width(for: item.title)
    }

    private var labelSize: CGSize {
        CGSize(width: labelWidth, height: RingLabelMetrics.height)
    }

    var body: some View {
        Button(action: action) {
            RingItemIconView(item: item, size: 22)
                .foregroundStyle(item == nil ? KeyFlowTheme.secondaryText : .white)
        }
        .buttonStyle(RingCircleButtonStyle(isEmphasized: isHovering || isSelected, isEmpty: item == nil))
        .overlay(alignment: .center) {
            if let item, let labelAngle {
                Text(item.title)
                    .font(.system(size: RingLabelMetrics.fontSize, weight: .semibold))
                    .foregroundStyle(isHovering || isSelected ? .white : KeyFlowTheme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: max(labelWidth - RingLabelMetrics.horizontalPadding * 2, 0))
                    .padding(.horizontal, RingLabelMetrics.horizontalPadding)
                    .padding(.vertical, RingLabelMetrics.verticalPadding)
                    .frame(width: labelWidth, height: RingLabelMetrics.height)
                    .background(isHovering || isSelected ? KeyFlowTheme.text : KeyFlowTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(KeyFlowTheme.border))
                    .fixedSize()
                    .offset(RingLabelMetrics.offset(angle: labelAngle, size: labelSize))
                    .allowsHitTesting(false)
            }
        }
        .onHover { isHovering = $0 }
        .accessibilityLabel(item?.title ?? "空操作位")
    }
}

private struct RingCircleButtonStyle: ButtonStyle {
    let isEmphasized: Bool
    let isEmpty: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 48, height: 48, alignment: .center)
            .background(isEmpty ? Color(hex: 0xE8E8E8) : KeyFlowTheme.text)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(isEmpty ? KeyFlowTheme.border : KeyFlowTheme.text, lineWidth: 2)
                    .padding(-3)
                    .opacity(isEmphasized && !configuration.isPressed ? 1 : 0)
            }
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .padding(3)
                    .opacity(configuration.isPressed && !isEmpty ? 1 : 0)
            }
            .shadow(color: .black.opacity(isEmpty ? 0.04 : 0.2), radius: 8, y: 6)
            .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
    }
}

struct RingSlotDropDelegate: DropDelegate {
    let index: Int
    let handler: (@Sendable (String, Int) -> Void)?

    func validateDrop(info: DropInfo) -> Bool {
        handler != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let handler else { return false }
        for provider in info.itemProviders(for: [.text]) {
            provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let string = object as? String else { return }
                DispatchQueue.main.async { handler(string, index) }
            }
        }
        return true
    }
}
