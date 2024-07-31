import AuthenticationServices

extension ASPresentationAnchor {
    /// A platform-specific anchor, intended to be used by ASAuthorizationController
    static var `default`: ASPresentationAnchor {
#if os(macOS)
        // FIXME: Figure out better fallback mechanisms here.
        // This will cause a new window to open _and remain open_
        return NSApplication.shared.mainWindow ?? ASPresentationAnchor()
#else
        return (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first?
            .rootViewController?
            .view
            .window
        ?? ASPresentationAnchor()
#endif
    }
}
