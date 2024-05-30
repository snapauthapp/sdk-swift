import AuthenticationServices

// MARK: ASAuthorizationControllerPresentationContextProviding
@available(macOS 12.0, iOS 15.0, tvOS 16.0, visionOS 1.0, *)
extension SnapAuth: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard anchor != nil else {
            // There's currently no logical path here since the three
            // entrypoints all set the anchor, but in case more direct control
            // paths are exposed this should prevent an unwrapping crash
            logger.error("Presentation anchor missing, providing default")
            return ASPresentationAnchor.default
        }
        return anchor!
    }
}
