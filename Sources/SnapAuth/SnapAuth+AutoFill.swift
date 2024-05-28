import AuthenticationServices

/// Adds AutoFill passkey support.
///
/// Due to platform limitations, this is only available on iOS and visionOS.
/// It is not (currently) supported on macOS, watchOS, tvOS, or Catalyst.
///
/// Also, it doesn't seem to work _even on_ supported platforms.
#if os(iOS) || os(visionOS)
extension SnapAuth {

    /// Starts the AutoFill process using a default ASPresentationAnchor
    @available(iOS 16.0, *)
    public func handleAutoFill(delegate: SnapAuthAutofillDelegate) async {
        await handleAutoFill(delegate: delegate, anchor: .default)
    }

    /// Use the specified anchor.
    /// This may be exposed publiy if needed, but the intent/goal is the default is (almost) always correct
    @available(iOS 16.0, *)
    internal func handleAutoFill(
        delegate: SnapAuthAutofillDelegate,
        anchor: ASPresentationAnchor
    ) async {
        self.anchor = anchor

        await handleAutoFill(delegate: delegate, presentationContextProvider: self)
    }

    /// Use the specified presentationContextProvider.
    /// Like with handleAutoFill(anchor:) this could get publicly exposed later but is for the "file a bug" case
    @available(iOS 16.0, *)
    internal func handleAutoFill(
        delegate: SnapAuthAutofillDelegate,
        presentationContextProvider: ASAuthorizationControllerPresentationContextProviding
    ) async {
        reset()
        state = .autofill
        autoFillDelegate = delegate
        let response = await api.makeRequest(
            path: "/auth/createOptions",
            body: [:] as [String:String],
            type: SACreateAuthOptionsResponse.self)

        guard case let .success(options) = response else {
            // TODO: decide how to handle AutoFill errors
            return
        }

        // AutoFill always only uses passkeys, so this is not configurable
        let authRequests = buildAuthRequests(
            from: options,
            authenticators: [.passkey])

        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = presentationContextProvider
        logger.debug("AF perform")
        controller.performAutoFillAssistedRequests()
    }

}
#endif

public protocol SnapAuthAutofillDelegate {
    func snapAuth(didAutofillWithResult result: SnapAuthResult)
}
