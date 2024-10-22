extension SnapAuth {
    /// Attempts to upgrade an existing account to use passkeys by creating one
    /// in the background.
    ///
    /// This should be called after a user signs in. Errors should not be
    /// displayed to the user, though may be logged.
    ///
    /// - Parameters:
    ///   - username: The username of the user, such as an email address or handle
    ///   - displayName: The proper name of the user. If omitted, name will be used.
    public func upgradeToPasskey(
        username: String,
        displayName: String? = nil
    ) async -> SnapAuthResult {
        if !SAAvailability.passkeyUpgrades {
            return .failure(.unsupportedOnPlatform)
        }

        return await startRegister(
            username: username,
            anchor: .default,
            displayName: displayName,
            authenticators: [.passkey],
            upgrade: true
        )
    }
}
