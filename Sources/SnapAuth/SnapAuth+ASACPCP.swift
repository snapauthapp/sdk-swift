import AuthenticationServices

// MARK: ASAuthConPresConProv
@available(macOS 12.0, iOS 15.0, tvOS 16.0, visionOS 1.0, *)
extension SnapAuth: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        logger.debug("presentation anchor")
        return anchor!
    }
}
