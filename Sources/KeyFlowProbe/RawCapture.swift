import Darwin
import Foundation
import IOKit.hid

func rawCapture(seconds: Double) {
    setbuf(stdout, nil)
    print("开始读取厂商原始报告 \(Int(seconds)) 秒。")
    let manager = createManager()
    let status = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    guard status == kIOReturnSuccess else {
        print("HID 打开失败：\(status)")
        return
    }
    IOHIDManagerRegisterInputReportCallback(manager, { _, _, sender, reportType, reportID, report, length in
        guard reportType == kIOHIDReportTypeInput, let sender else { return }
        let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
        let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey) ?? 0
        guard usagePage == 0x8C || usagePage == 0xFF60 else { return }
        let bytes = UnsafeBufferPointer(start: report, count: length).map { String(format: "%02x", $0) }.joined(separator: " ")
        print("usagePage=\(hex(usagePage)) report=\(reportID) length=\(length): \(bytes)")
    }, nil)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    print("原始报告采集结束。")
}
