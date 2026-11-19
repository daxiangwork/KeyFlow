import Foundation
import IOKit.hid

@MainActor
final class TriggerRecognizer {
    final class ButtonState {
        var isDown = false
        var longPressFired = false
        var awaitingDoubleRelease = false
        var longPressWorkItem: DispatchWorkItem?
        var clickWorkItem: DispatchWorkItem?
    }

    var onTrigger: ((TriggerButton, TriggerGesture) -> Void)?
    private var states: [TriggerButton: ButtonState] = [:]

    func process(_ button: TriggerButton, isPressed: Bool) {
        let state = states[button, default: ButtonState()]
        states[button] = state
        if isPressed { press(button, state: state) } else { release(button, state: state) }
    }

    func reset() {
        for state in states.values {
            state.longPressWorkItem?.cancel()
            state.clickWorkItem?.cancel()
        }
        states.removeAll()
    }

    private func press(_ button: TriggerButton, state: ButtonState) {
        guard !state.isDown else { return }
        state.isDown = true
        state.longPressFired = false

        if let pendingClick = state.clickWorkItem {
            pendingClick.cancel()
            state.clickWorkItem = nil
            state.awaitingDoubleRelease = true
        }

        let longPress = DispatchWorkItem { [weak self, weak state] in
            guard let self, let state, state.isDown else { return }
            state.longPressFired = true
            state.awaitingDoubleRelease = false
            state.clickWorkItem?.cancel()
            state.clickWorkItem = nil
            self.onTrigger?(button, .longPress)
        }
        state.longPressWorkItem = longPress
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: longPress)
    }

    private func release(_ button: TriggerButton, state: ButtonState) {
        guard state.isDown else { return }
        state.isDown = false
        state.longPressWorkItem?.cancel()
        state.longPressWorkItem = nil

        guard !state.longPressFired else {
            state.longPressFired = false
            return
        }
        if state.awaitingDoubleRelease {
            state.awaitingDoubleRelease = false
            onTrigger?(button, .doubleClick)
            return
        }

        let click = DispatchWorkItem { [weak self, weak state] in
            guard let self, let state else { return }
            state.clickWorkItem = nil
            self.onTrigger?(button, .singleClick)
        }
        state.clickWorkItem = click
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: click)
    }
}

final class HIDInputRouter: @unchecked Sendable {
    static let shared = HIDInputRouter()

    let suppressionRegistry = SuppressionRegistry()
    private let lock = NSLock()
    private var handler: ((TriggerButton, Bool) -> Void)?
    private var suppressionEnabled = false

    func setHandler(_ handler: @escaping (TriggerButton, Bool) -> Void) {
        lock.lock()
        self.handler = handler
        lock.unlock()
    }

    func setSuppressionEnabled(_ enabled: Bool) {
        lock.lock()
        suppressionEnabled = enabled
        lock.unlock()
        if !enabled { suppressionRegistry.clear() }
    }

    func route(button: TriggerButton, token: SuppressionToken, isPressed: Bool) {
        lock.lock()
        let enabled = suppressionEnabled
        let handler = self.handler
        lock.unlock()
        if enabled { suppressionRegistry.register(token) }
        handler?(button, isPressed)
    }
}

@MainActor
final class HIDMonitor: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastSignal = "尚未收到鼠标信号"
    @Published private(set) var errorMessage: String?

    let suppressionRegistry = HIDInputRouter.shared.suppressionRegistry
    private let recognizer = TriggerRecognizer()
    private var manager: IOHIDManager?

    var onTrigger: ((TriggerButton, TriggerGesture) -> Void)? {
        get { recognizer.onTrigger }
        set { recognizer.onTrigger = newValue }
    }

    init() {
        HIDInputRouter.shared.setHandler { [weak self] button, isPressed in
            DispatchQueue.main.async {
                self?.lastSignal = "\(button.title) · \(isPressed ? "按下" : "松开")"
                self?.recognizer.process(button, isPressed: isPressed)
            }
        }
    }

    func start() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x362D] as CFDictionary)
        self.manager = manager

        IOHIDManagerRegisterInputValueCallback(manager, { _, _, _, value in
            let element = IOHIDValueGetElement(value)
            let usagePage = Int(IOHIDElementGetUsagePage(element))
            let usage = Int(IOHIDElementGetUsage(element))
            let isPressed = IOHIDValueGetIntegerValue(value) != 0
            guard let input = HIDMonitor.resolve(usagePage: usagePage, usage: usage) else { return }
            HIDInputRouter.shared.route(button: input.button, token: input.token, isPressed: isPressed)
        }, nil)

        let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard status == kIOReturnSuccess else {
            errorMessage = "无法读取 JZ M5。请检查输入监控权限后重新连接。"
            return
        }
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        refreshConnection()
    }

    func refreshConnection() {
        guard let manager else { return }
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        isConnected = !devices.isEmpty
        if !isConnected {
            recognizer.reset()
            lastSignal = "等待设备连接"
        }
    }

    func resetTriggers() {
        recognizer.reset()
        suppressionRegistry.clear()
    }

    private static func resolve(usagePage: Int, usage: Int) -> (button: TriggerButton, token: SuppressionToken)? {
        switch (usagePage, usage) {
        case (0x07, 0x68): (.middle, .keyboard(105))
        case (0x07, 0x69): (.forward, .keyboard(107))
        case (0x07, 0x6A): (.backward, .keyboard(113))
        case (0x07, 0x06): (.forward, .keyboard(8))
        case (0x07, 0x19): (.backward, .keyboard(9))
        case (0x0C, 0x029F): (.middle, .keyboard(160))
        case (0x09, 3): (.middle, .mouse(2))
        case (0x09, 5): (.forward, .mouse(4))
        case (0x09, 4): (.backward, .mouse(3))
        default: nil
        }
    }
}
