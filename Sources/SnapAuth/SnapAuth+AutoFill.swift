import AuthenticationServices

/**
 Adds AutoFill passkey support.

 Due to platform limitations, this is only available on iOS.
 It is not (currently) supported on macOS, watchOS, tvOS, or Catalyst.
 */
#if os(iOS)
extension SnapAuth {
    /**
     Starts the AutoFill process using a default ASPresentationAnchor
     */
    @available(iOS 16.0, *)
    public func handleAutoFill() async {
        await handleAutoFill(anchor: ASPresentationAnchor())
    }

    @available(iOS 16.0, *)
    public func handleAutoFill(anchor: ASPresentationAnchor) async {
        self.anchor = anchor

        await handleAutoFill(presentationContextProvider: self)
    }


    @available(iOS 16.0, *)
    public func handleAutoFill(presentationContextProvider: ASAuthorizationControllerPresentationContextProviding) async {
        reset()
        logger.debug("AF PCP start")
        let parsed = await api.makeRequest(
            path: "/auth/createOptions",
            body: [:] as [String:String],
            type: SACreateAuthOptionsResponse.self)!

        /// TODO: passkey only here
        let authRequests = buildAuthRequests(from: parsed.result)

        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = presentationContextProvider
        logger.debug("AF perform")
        controller.performAutoFillAssistedRequests()
    }
}
#endif
