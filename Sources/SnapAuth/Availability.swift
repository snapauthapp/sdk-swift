/// Platform availability hints for passkeys and hardware authenticators
struct SAAvailability {

    /// Indicates whether passkey autofill requests are supported on the current
    /// platform/device.
    static var autofill: Bool {
#if (os(iOS) || os(visionOS))
        if #available(iOS 16, visionOS 1, *) {
            return true
        }
#endif
        return false
    }

    /// Indicates whether external security keys are supported on the current
    /// platform/device.
    static var securityKeys: Bool {
#if HARDWARE_KEY_SUPPORT
        return true
#else
        return false
#endif
    }

    /// Indicates whether automatic passkey upgrades are supported on the
    /// current platform/device.
    static var passkeyUpgrades: Bool {
#if (os(iOS) || os(macOS) || os(visionOS))
        if #available(iOS 18, macOS 15, visionOS 2, *) {
            return true
        }
#endif
        return false
    }
}
