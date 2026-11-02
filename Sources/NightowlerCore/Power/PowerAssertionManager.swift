import Foundation
import IOKit.pwr_mgt

public final class PowerAssertionManager: @unchecked Sendable {
    public static let shared = PowerAssertionManager()

    private let lock = NSLock()
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0

    public var holdsSystemAssertion: Bool {
        lock.lock()
        defer { lock.unlock() }
        return systemAssertionID != 0
    }

    public var holdsDisplayAssertion: Bool {
        lock.lock()
        defer { lock.unlock() }
        return displayAssertionID != 0
    }

    public init() {}

    deinit {
        releaseAll()
    }

    @discardableResult
    public func createSystemAssertion(reason: String = "Nightowler Power Assertion") -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if systemAssertionID != 0 {
            return true
        }

        let type = kIOPMAssertionTypePreventUserIdleSystemSleep as CFString
        let name = reason as CFString
        var assertionID: IOPMAssertionID = 0

        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &assertionID
        )

        if result == kIOReturnSuccess {
            systemAssertionID = assertionID
            return true
        } else {
            return false
        }
    }

    public func releaseSystemAssertion() {
        lock.lock()
        defer { lock.unlock() }

        if systemAssertionID != 0 {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
        }
    }

    @discardableResult
    public func createDisplayAssertion(reason: String = "Nightowler Display Sleep Prevention") -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if displayAssertionID != 0 {
            return true
        }

        let type = kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString
        let name = reason as CFString
        var assertionID: IOPMAssertionID = 0

        let result = IOPMAssertionCreateWithName(
            type,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            name,
            &assertionID
        )

        if result == kIOReturnSuccess {
            displayAssertionID = assertionID
            return true
        } else {
            return false
        }
    }

    public func releaseDisplayAssertion() {
        lock.lock()
        defer { lock.unlock() }

        if displayAssertionID != 0 {
            IOPMAssertionRelease(displayAssertionID)
            displayAssertionID = 0
        }
    }

    public func releaseAll() {
        releaseSystemAssertion()
        releaseDisplayAssertion()
    }
}
