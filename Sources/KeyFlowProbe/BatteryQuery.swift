import Foundation
import IOKit.hid

private final class BatteryQueryState {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
    var percent: Int?
    var isCharging = false

    init() { buffer.initialize(repeating: 0, count: 256) }
    deinit { buffer.deinitialize(count: 256); buffer.deallocate() }
}

func batteryQuery(seconds: Double) {
    let manager = createManager()
    guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
          let receiver = devices.first(where: {
              intProperty($0, kIOHIDPrimaryUsagePageKey) == 0x8C &&
              intProperty($0, kIOHIDPrimaryUsageKey) == 1
          }) else {
        print("未找到 JZ M5 0x008C 配置接口。")
        return
    }
    let openResult = IOHIDDeviceOpen(receiver, IOOptionBits(kIOHIDOptionsTypeNone))
    guard openResult == kIOReturnSuccess else {
        print("打开接口失败：\(String(format: "0x%08X", openResult))")
        return
    }
    defer { IOHIDDeviceClose(receiver, IOOptionBits(kIOHIDOptionsTypeNone)) }

    let state = BatteryQueryState()
    let retained = Unmanaged.passRetained(state)
    defer { retained.release() }
    let callback: IOHIDReportCallback = { context, _, _, _, reportID, report, length in
        guard let context else { return }
        let state = Unmanaged<BatteryQueryState>.fromOpaque(context).takeUnretainedValue()
        let bytes = Array(UnsafeBufferPointer(start: report, count: length))
        print("响应 report=\(reportID) length=\(length): \(bytes.map { String(format: "%02x", $0) }.joined(separator: " "))")
        guard reportID == 0xB4 else { return }
        var payload = bytes
        if payload.first == 0xB4 { payload.removeFirst() }
        guard payload.count > 19, payload[0] == 0x06 else { return }
        state.percent = Int(payload[19] & 0x7F)
        state.isCharging = payload[19] & 0x80 != 0
    }
    IOHIDDeviceRegisterInputReportCallback(receiver, state.buffer, 256, callback, retained.toOpaque())
    IOHIDDeviceScheduleWithRunLoop(receiver, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
    defer { IOHIDDeviceUnscheduleFromRunLoop(receiver, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) }

    var request = [UInt8](repeating: 0, count: 64)
    request[0] = 0xB3
    request[1] = 0x06
    let result = request.withUnsafeBytes {
        IOHIDDeviceSetReport(receiver, kIOHIDReportTypeOutput, 0xB3, $0.baseAddress!, request.count)
    }
    guard result == kIOReturnSuccess else {
        print("发送查询失败：\(String(format: "0x%08X", result))")
        return
    }
    print("已发送 B3 / 06 电量查询。")

    let deadline = Date().addingTimeInterval(seconds)
    while state.percent == nil && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }
    if let percent = state.percent {
        print("读取成功：电量 \(percent)%，充电状态 \(state.isCharging ? "正在充电" : "未充电")")
    } else {
        print("超时：未收到有效 B4 电量响应。")
    }
}
