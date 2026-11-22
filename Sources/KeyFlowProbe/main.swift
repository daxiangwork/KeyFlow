import CoreGraphics
import Darwin
import Foundation
import IOKit.hid

let vendorID = 0x362D

func property(_ device: IOHIDDevice, _ key: String) -> Any? {
    IOHIDDeviceGetProperty(device, key as CFString)
}

func intProperty(_ device: IOHIDDevice, _ key: String) -> Int? {
    property(device, key) as? Int
}

func hex(_ value: Int) -> String {
    String(format: "0x%04X", value)
}

func createManager() -> IOHIDManager {
    let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
    let matching: [String: Any] = [kIOHIDVendorIDKey: vendorID]
    IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    return manager
}

func listDevices() {
    let manager = createManager()
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>, !devices.isEmpty else {
        print("未发现 JZ M5。请确认鼠标已开机，并通过蓝牙、有线或 2.4G 接收器连接。")
        return
    }

    let sortedDevices = devices.sorted {
        intProperty($0, kIOHIDLocationIDKey) ?? 0 < intProperty($1, kIOHIDLocationIDKey) ?? 0
    }
    print("发现 \(sortedDevices.count) 个匹配的 HID 接口：")
    for (index, device) in sortedDevices.enumerated() {
        let product = property(device, kIOHIDProductKey) as? String ?? "未知"
        let productID = intProperty(device, kIOHIDProductIDKey) ?? 0
        let transport = property(device, kIOHIDTransportKey) as? String ?? "未知"
        let location = intProperty(device, kIOHIDLocationIDKey) ?? 0
        let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey) ?? 0
        let usage = intProperty(device, kIOHIDPrimaryUsageKey) ?? 0
        let maxInput = intProperty(device, kIOHIDMaxInputReportSizeKey) ?? 0
        let maxOutput = intProperty(device, kIOHIDMaxOutputReportSizeKey) ?? 0
        let maxFeature = intProperty(device, kIOHIDMaxFeatureReportSizeKey) ?? 0
        print("[\(index + 1)] \(product)")
        print("    VID:PID \(hex(vendorID)):\(hex(productID))  Location \(hex(location))  Transport \(transport)")
        print("    Primary Usage Page \(hex(usagePage)), Usage \(hex(usage))")
        print("    Report sizes — Input: \(maxInput), Output: \(maxOutput), Feature: \(maxFeature)")
    }
}

func deviceName(_ device: IOHIDDevice) -> String {
    let location = intProperty(device, kIOHIDLocationIDKey) ?? 0
    let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey) ?? 0
    let usage = intProperty(device, kIOHIDPrimaryUsageKey) ?? 0
    return "HID \(hex(location)) [\(hex(usagePage)):\(hex(usage))]"
}

func capture(seconds: Double) {
    setbuf(stdout, nil)
    print("开始采集 \(Int(seconds)) 秒。仅记录输入，不会修改鼠标设置。")

    let manager = createManager()
    let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    print(openStatus == kIOReturnSuccess ? "HID 监听已启动。" : "HID 打开失败：\(String(format: "0x%08X", openStatus))")
    IOHIDManagerRegisterInputValueCallback(manager, { _, _, sender, value in
        guard let sender else { return }
        let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
        let element = IOHIDValueGetElement(value)
        let usagePage = Int(IOHIDElementGetUsagePage(element))
        let usage = Int(IOHIDElementGetUsage(element))
        guard usagePage != 1 else { return }
        let number = IOHIDValueGetIntegerValue(value)
        let reportID = Int(IOHIDElementGetReportID(element))
        print("\(deviceName(device)) report=\(reportID) usagePage=\(hex(usagePage)) usage=\(hex(usage)) value=\(number)")
    }, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    let mask: CGEventMask =
        (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) |
        (CGEventMask(1) << CGEventType.otherMouseUp.rawValue) |
        (CGEventMask(1) << CGEventType.scrollWheel.rawValue) |
        (CGEventMask(1) << CGEventType.keyDown.rawValue) |
        (CGEventMask(1) << CGEventType.keyUp.rawValue) |
        (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

    if let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: mask,
        callback: { _, type, event, _ in
            if type == .otherMouseDown || type == .otherMouseUp {
                let button = event.getIntegerValueField(.mouseEventButtonNumber)
                print("macOS \(type == .otherMouseDown ? "按下" : "松开") button=\(button)")
            } else if type == .scrollWheel {
                let vertical = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                let horizontal = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
                print("macOS 滚动 vertical=\(vertical) horizontal=\(horizontal)")
            } else if type == .keyDown || type == .keyUp || type == .flagsChanged {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                var modifiers: [String] = []
                if event.flags.contains(.maskCommand) { modifiers.append("Command") }
                if event.flags.contains(.maskShift) { modifiers.append("Shift") }
                if event.flags.contains(.maskAlternate) { modifiers.append("Option") }
                if event.flags.contains(.maskControl) { modifiers.append("Control") }
                let state = type == .keyDown ? "按下" : type == .keyUp ? "松开" : "修饰键"
                print("macOS 键盘\(state) keyCode=\(keyCode) modifiers=\(modifiers.joined(separator: "+"))")
            }
            return Unmanaged.passUnretained(event)
        },
        userInfo: nil
    ) {
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("macOS 事件监听已启动。")
    } else {
        print("macOS 事件监听不可用；请为当前终端开启“输入监控”权限。HID 监听仍会继续。")
    }

    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    print("采集结束。")
}

let arguments = CommandLine.arguments
if arguments.contains("demo") {
    var seconds = 60.0
    if let index = arguments.firstIndex(of: "--seconds"), index + 1 < arguments.count,
       let value = Double(arguments[index + 1]), value > 0 {
        seconds = value
    }
    runSmartActionDemo(seconds: seconds)
} else if arguments.contains("battery") {
    batteryQuery(seconds: 3)
} else if arguments.contains("raw") {
    var seconds = 30.0
    if let index = arguments.firstIndex(of: "--seconds"), index + 1 < arguments.count,
       let value = Double(arguments[index + 1]), value > 0 {
        seconds = value
    }
    rawCapture(seconds: seconds)
} else if arguments.contains("capture") {
    var seconds = 45.0
    if let index = arguments.firstIndex(of: "--seconds"), index + 1 < arguments.count,
       let value = Double(arguments[index + 1]), value > 0 {
        seconds = value
    }
    capture(seconds: seconds)
} else {
    listDevices()
}
