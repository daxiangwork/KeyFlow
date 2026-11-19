import AppKit
import CoreGraphics
import Darwin
import Foundation
import IOKit.hid

func runSmartActionDemo(seconds: Double) {
    setbuf(stdout, nil)
    print("Smart Action 演示已启动：按中键打开计算器，并拦截原来的调度中心。")

    let manager = createManager()
    let openStatus = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openStatus == kIOReturnSuccess else {
        print("HID 打开失败：\(String(format: "0x%08X", openStatus))")
        return
    }

    IOHIDManagerRegisterInputValueCallback(manager, { _, _, _, value in
        let element = IOHIDValueGetElement(value)
        let usagePage = Int(IOHIDElementGetUsagePage(element))
        let usage = Int(IOHIDElementGetUsage(element))
        guard usagePage == 0x0C, usage == 0x029F, IOHIDValueGetIntegerValue(value) == 1 else { return }

        print("检测到 JZ M5 中键，执行动作：打开计算器")
        NSWorkspace.shared.openApplication(
            at: URL(fileURLWithPath: "/System/Applications/Calculator.app"),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                print("动作执行失败：\(error.localizedDescription)")
            } else {
                print("动作执行成功。")
            }
        }
    }, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

    let mask: CGEventMask =
        (CGEventMask(1) << CGEventType.keyDown.rawValue) |
        (CGEventMask(1) << CGEventType.keyUp.rawValue)

    let trusted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    print(trusted ? "辅助功能权限已授权。" : "请为当前宿主应用开启“辅助功能”权限。")

    guard let tap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: mask,
        callback: { _, type, event, _ in
            guard type == .keyDown || type == .keyUp else { return Unmanaged.passUnretained(event) }
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == 160 else { return Unmanaged.passUnretained(event) }
            print("已拦截调度中心原始事件。")
            return nil
        },
        userInfo: nil
    ) else {
        print("无法创建事件拦截器。请检查“输入监控”和“辅助功能”权限。")
        return
    }

    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
    print("演示运行 \(Int(seconds)) 秒，请按中键测试。")

    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    print("演示结束，鼠标原始行为已恢复。")
}
