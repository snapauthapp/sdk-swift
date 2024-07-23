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
    public func handleAutoFill(delegate: SnapAuthAutoFillDelegate) {
        handleAutoFill(delegate: delegate, anchor: .default)
    }

    /// Use the specified anchor.
    /// This may be exposed publiy if needed, but the intent/goal is the default is (almost) always correct
    @available(iOS 16.0, *)
    internal func handleAutoFill(
        delegate: SnapAuthAutoFillDelegate,
        anchor: ASPresentationAnchor
    ) {
        self.anchor = anchor

        handleAutoFill(delegate: delegate, presentationContextProvider: self)
    }

    /// Use the specified presentationContextProvider.
    /// Like with handleAutoFill(anchor:) this could get publicly exposed later but is for the "file a bug" case
    @available(iOS 16.0, *)
    internal func handleAutoFill(
        delegate: SnapAuthAutoFillDelegate,
        presentationContextProvider: ASAuthorizationControllerPresentationContextProviding
    ) {
        reset()
        state = .autoFill
        autoFillDelegate = delegate
        Task {
            let response = await api.makeRequest(
                path: "/assertion/options",
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

}
#endif
