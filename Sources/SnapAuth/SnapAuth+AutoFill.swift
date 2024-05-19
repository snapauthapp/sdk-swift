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
    public func handleAutoFill() async {
        await handleAutoFill(anchor: .default)
    }

    /// Use the specified anchor.
    /// This may be exposed publiy if needed, but the intent/goal is the default is (almost) always correct
    @available(iOS 16.0, *)
    internal func handleAutoFill(anchor: ASPresentationAnchor) async {
        self.anchor = anchor

        await handleAutoFill(presentationContextProvider: self)
    }

    /// Use the specified presentationContextProvider.
    /// Like with handleAutoFill(anchor:) this could get publicly exposed later but is for the "file a bug" case
    @available(iOS 16.0, *)
    internal func handleAutoFill(
        presentationContextProvider: ASAuthorizationControllerPresentationContextProviding
    ) async {
        reset()
        state = .autofill
        let parsed = await api.makeRequest(
            path: "/auth/createOptions",
            body: [:] as [String:String],
            type: SACreateAuthOptionsResponse.self)!

        guard parsed.result != nil else {
            logger.error("no result for AF")
            // TODO: bubble this up
            return
        }

        // AutoFill always only uses passkeys, so this is not configurable
        let authRequests = buildAuthRequests(
            from: parsed.result!,
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
