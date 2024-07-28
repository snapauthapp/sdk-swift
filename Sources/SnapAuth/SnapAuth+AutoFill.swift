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
    public func handleAutoFill() async -> SnapAuthResult {
        await handleAutoFill(anchor: .default)
    }

    /// Use the specified anchor.
    /// This may be exposed publiy if needed, but the intent/goal is the default is (almost) always correct
    internal func handleAutoFill(
        anchor: ASPresentationAnchor
    ) async -> SnapAuthResult {
        self.anchor = anchor

        return await handleAutoFill(presentationContextProvider: self)
    }

    /// Use the specified presentationContextProvider.
    /// Like with handleAutoFill(anchor:) this could get publicly exposed later but is for the "file a bug" case
    internal func handleAutoFill(
        presentationContextProvider: ASAuthorizationControllerPresentationContextProviding
    ) async -> SnapAuthResult {
        reset()
        // TODO: filter other unsupported platforms (do this better than the top-level ifdef)
        guard #available(iOS 16, *) else {
            return .failure(.unsupportedOnPlatform)
        }

        let response = await self.api.makeRequest(
            path: "/assertion/options",
            body: [:] as [String:String],
            type: SACreateAuthOptionsResponse.self)

        guard case let .success(options) = response else {
            // TODO: decide how to handle AutoFill errors
            return .failure(response.getError()!)
        }

        // AutoFill always only uses passkeys, so this is not configurable
        let authRequests = self.buildAuthRequests(
            from: options,
            authenticators: [.passkey])

        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = presentationContextProvider
        logger.debug("AF perform")
        return await withCheckedContinuation { continuation in
            assert(self.continuation == nil)
            self.continuation = continuation // as! CheckedContinuation<SnapAuthResult, Never>
            controller.performAutoFillAssistedRequests()
        }
    }

}
#endif
