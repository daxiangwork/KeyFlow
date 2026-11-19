import Foundation
import IOKit.hid

struct BatteryReading: Equatable, Sendable {
    let percent: Int
    let isCharging: Bool
}

enum BatteryReadError: LocalizedError {
    case noReceiver
    case open(IOReturn)
    case send(IOReturn)
    case timeout

    var errorDescription: String? {
        switch self {
        case .noReceiver: "未找到 JZ M5 2.4G 接收器。"
        case .open(let result): "打开电量接口失败：\(String(format: "0x%08X", result))。"
        case .send(let result): "发送电量查询失败：\(String(format: "0x%08X", result))。"
        case .timeout: "电量查询超时，请关闭网页驱动后重试。"
        }
    }
}

enum JZM5BatteryProtocol {
    static func readBattery() throws -> BatteryReading {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: 0x362D,
            kIOHIDProductIDKey: 0xD107
        ] as CFDictionary)
        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else { throw BatteryReadError.open(managerResult) }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }

        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let receiver = devices.first(where: {
                  hidNumber($0, kIOHIDPrimaryUsagePageKey) == 0x008C &&
                  hidNumber($0, kIOHIDPrimaryUsageKey) == 0x0001
              }) else { throw BatteryReadError.noReceiver }
        let openResult = IOHIDDeviceOpen(receiver, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else { throw BatteryReadError.open(openResult) }
        defer { IOHIDDeviceClose(receiver, IOOptionBits(kIOHIDOptionsTypeNone)) }

        let state = BatteryQueryState()
        let retained = Unmanaged.passRetained(state)
        defer { retained.release() }
        IOHIDDeviceRegisterInputReportCallback(receiver, state.buffer, 256, batteryInputCallback, retained.toOpaque())
        IOHIDDeviceScheduleWithRunLoop(receiver, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        defer { IOHIDDeviceUnscheduleFromRunLoop(receiver, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) }

        var request = [UInt8](repeating: 0, count: 64)
        request[0] = 0xB3
        request[1] = 0x06
        let result = request.withUnsafeBytes {
            IOHIDDeviceSetReport(receiver, kIOHIDReportTypeOutput, 0xB3, $0.baseAddress!, request.count)
        }
        guard result == kIOReturnSuccess else { throw BatteryReadError.send(result) }

        let deadline = Date().addingTimeInterval(3)
        while state.reading == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        guard let reading = state.reading else { throw BatteryReadError.timeout }
        return reading
    }

    private static func hidNumber(_ device: IOHIDDevice, _ key: String) -> Int? {
        IOHIDDeviceGetProperty(device, key as CFString) as? Int
    }
}

private final class BatteryQueryState {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 256)
    var reading: BatteryReading?

    init() { buffer.initialize(repeating: 0, count: 256) }
    deinit { buffer.deinitialize(count: 256); buffer.deallocate() }
}

private let batteryInputCallback: IOHIDReportCallback = { context, _, _, _, reportID, report, length in
    guard reportID == 0xB4, let context else { return }
    let state = Unmanaged<BatteryQueryState>.fromOpaque(context).takeUnretainedValue()
    var payload = Array(UnsafeBufferPointer(start: report, count: length))
    if payload.first == 0xB4 { payload.removeFirst() }
    guard payload.count > 19, payload[0] == 0x06 else { return }
    state.reading = BatteryReading(
        percent: Int(payload[19] & 0x7F),
        isCharging: payload[19] & 0x80 != 0
    )
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var reading: BatteryReading?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false

    private var timer: Timer?

    var menuTitle: String {
        guard let reading else { return "鼠标电量：--" }
        return "鼠标电量：\(reading.percent)%\(reading.isCharging ? " · 充电中" : "")"
    }

    var menuDetail: String {
        var parts: [String] = []
        if let lastUpdated { parts.append("更新于 \(lastUpdated.formatted(date: .omitted, time: .shortened))") }
        if let lastError { parts.append(lastError) }
        return parts.isEmpty ? "JZ M5 2.4G 电量" : parts.joined(separator: " · ")
    }

    func start() {
        refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            guard let self, self.reading == nil else { return }
            self.refresh()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            let result = await Task.detached {
                Result { try JZM5BatteryProtocol.readBattery() }
            }.value
            self.apply(result)
        }
    }

    private func apply(_ result: Result<BatteryReading, Error>) {
        switch result {
        case .success(let reading):
            self.reading = reading
            lastUpdated = Date()
            lastError = nil
        case .failure(let error):
            lastError = error.localizedDescription
        }
        isRefreshing = false
    }
}
