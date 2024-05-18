import AuthenticationServices

#if os(macOS)
// FIXME: Figure out better fallback mechanisms here.
// This will cause a new window to open _and remain open_
fileprivate let defaultPresentationAnchor: ASPresentationAnchor = NSApplication.shared.mainWindow ?? ASPresentationAnchor()
#else
fileprivate let defaultPresentationAnchor: ASPresentationAnchor = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController?.view.window ?? ASPresentationAnchor()
#endif

extension ASPresentationAnchor {
    /// A platform-specific anchor, intended to be used by ASAuthorizationController
    static let `default` = defaultPresentationAnchor
}
