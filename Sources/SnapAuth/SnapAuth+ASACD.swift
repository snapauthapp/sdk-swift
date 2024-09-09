import AuthenticationServices

// MARK: - ASAuthorizationControllerDelegate
@available(macOS 12.0, iOS 15.0, visionOS 1.0, tvOS 16.0, *)
extension SnapAuth: ASAuthorizationControllerDelegate {

    /// Delegate method for ASAuthorizationController.
    /// This should not be called directly.
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        logger.debug("ASACD error")
        guard let asError = error as? ASAuthorizationError else {
            logger.error("authorizationController didCompleteWithError error was not an ASAuthorizationError")
            sendError(.unknown)
            return
        }

        sendError(asError.code.snapAuthError)
        // The start call can SILENTLY produce this error which never makes it into this handler
        // ASAuthorizationController credential request failed with error: Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004 "(null)"
    }

    /// Delegate method for ASAuthorizationController.
    /// This should not be called directly.
    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        logger.debug("ASACD did complete")


        switch authorization.credential {
        case is ASAuthorizationPublicKeyCredentialAssertion:
            handleAssertion(authorization.credential as! ASAuthorizationPublicKeyCredentialAssertion)
        case is ASAuthorizationPublicKeyCredentialRegistration:
            handleRegistration(authorization.credential as! ASAuthorizationPublicKeyCredentialRegistration)
        default:
            logger.error("Unexpected credential type \(String(describing: type(of: authorization.credential)))")
            sendError(.unexpectedAuthorizationType)
        }
    }

    private func sendError(_ error: SnapAuthError) {
        continuation?.resume(returning: .failure(error))
        continuation = nil
    }

    private func handleRegistration(
        _ registration: ASAuthorizationPublicKeyCredentialRegistration
    ) {
        logger.info("got a registration response")

        let credentialId = Base64URL(from: registration.credentialID)

        /*
         Leaving transports out for now
        if let secKey = registration as? ASAuthorizationSecurityKeyPublicKeyCredentialRegistration {
            if #available(iOS 17.5, *) {
                let transports = secKey.transports.map { Transport(from: $0) }
            } else {
                // Fallback on earlier versions
            }
        }
         */
        guard registration.rawAttestationObject != nil else {
            // This may change in the future?
            logger.error("No attestation in registration response")
            sendError(.registrationDataMissing)
            return
        }


        let response = SAProcessRegisterRequest.RegCredential.RegResponse(
            clientDataJSON: Base64URL(from: registration.rawClientDataJSON),
            attestationObject: Base64URL(from: registration.rawAttestationObject!),
            transports: [])
        let credential = SAProcessRegisterRequest.RegCredential(
            rawId: credentialId,
            response: response)
        let body = SAProcessRegisterRequest(credential: credential)

        Task {
            let response = await api.makeRequest(
                path: "/attestation/process",
                body: body,
                type: SAProcessAuthResponse.self) // TODO: rename this type
            guard case let .success(processAuth) = response else {
                logger.debug("/attestation/process error")
                sendError(response.getError()!)
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthTokenInfo(
                token: processAuth.token,
                expiresAt: processAuth.expiresAt)

            assert(continuation != nil)
            continuation?.resume(returning: .success(rewrapped))
            continuation = nil
        }
    }

    private func handleAssertion(
        _ assertion: ASAuthorizationPublicKeyCredentialAssertion
    ) {

        // This can (will always?) be `nil` when using, at least, a hardware key
        let userHandle = assertion.userID != nil
            ? Base64URL(from: assertion.userID)
            : nil

        // TODO: If userHandle is nil, guard that we have userInfo since it's required on the BE


        let credentialId = Base64URL(from: assertion.credentialID)
        let response = SAProcessAuthRequest.SACredential.Response(
            authenticatorData: Base64URL(from: assertion.rawAuthenticatorData),
            clientDataJSON: Base64URL(from: assertion.rawClientDataJSON),
            signature: Base64URL(from: assertion.signature),
            userHandle: userHandle)

        let cCrd = SAProcessAuthRequest.SACredential(
            rawId: credentialId,
            response: response)
        let body = SAProcessAuthRequest(
            credential: cCrd,
            user: authenticatingUser)
        logger.debug("made a body")
//        logger.debug("user id \(assertion.userID.base64EncodedString())")
        Task {
            let response = await api.makeRequest(
                path: "/assertion/process",
                body: body,
                type: SAProcessAuthResponse.self)
            guard case let .success(authResponse) = response else {
                logger.debug("/assertion/process error")
                sendError(response.getError()!)
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthTokenInfo(
                token: authResponse.token,
                expiresAt: authResponse.expiresAt)

            assert(continuation != nil)
            continuation?.resume(returning: .success(rewrapped))
            continuation = nil
        }

    }
// tvOS only? Probably not needed.
//    public func authorizationController(_ controller: ASAuthorizationController, didCompleteWithCustomMethod method: ASAuthorizationCustomMethod) {
//        if method == .other {
//
//        }
//    }
}

