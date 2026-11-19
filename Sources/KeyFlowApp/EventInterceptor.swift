import CoreGraphics
import Foundation

enum SuppressionToken: Hashable {
    case keyboard(Int)
    case mouse(Int)
}

final class SuppressionRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var registrations: [SuppressionToken: [Date]] = [:]

    func register(_ token: SuppressionToken) {
        lock.lock()
        defer { lock.unlock() }
        removeExpiredLocked()
        registrations[token, default: []].append(Date())
    }

    func consume(_ token: SuppressionToken) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        removeExpiredLocked()
        guard var dates = registrations[token], !dates.isEmpty else { return false }
        dates.removeFirst()
        if dates.isEmpty { registrations.removeValue(forKey: token) } else { registrations[token] = dates }
        return true
    }

    func clear() {
        lock.lock()
        registrations.removeAll()
        lock.unlock()
    }

    private func removeExpiredLocked() {
        let cutoff = Date().addingTimeInterval(-0.4)
        registrations = registrations.compactMapValues { dates in
            let valid = dates.filter { $0 >= cutoff }
            return valid.isEmpty ? nil : valid
        }
    }
}

@MainActor
final class EventInterceptor {
    private let registry: SuppressionRegistry
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(registry: SuppressionRegistry) {
        self.registry = registry
    }

    func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.otherMouseDown.rawValue) |
            (CGEventMask(1) << CGEventType.otherMouseUp.rawValue)
        guard let createdTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, _ in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    let tap = unsafeBitCast(proxy, to: CFMachPort.self)
                    CGEvent.tapEnable(tap: tap, enable: true)
                    return Unmanaged.passUnretained(event)
                }

                let token: SuppressionToken?
                if type == .keyDown || type == .keyUp {
                    token = .keyboard(Int(event.getIntegerValueField(.keyboardEventKeycode)))
                } else if type == .otherMouseDown || type == .otherMouseUp {
                    token = .mouse(Int(event.getIntegerValueField(.mouseEventButtonNumber)))
                } else {
                    token = nil
                }
                if let token, HIDInputRouter.shared.suppressionRegistry.consume(token) { return nil }
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        ) else {
            return false
        }

        tap = createdTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, createdTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: createdTap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        tap = nil
        registry.clear()
    }
}
