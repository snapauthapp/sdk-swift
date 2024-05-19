import AuthenticationServices

// MARK: - ASAuthorizationControllerDelegate
@available(macOS 12.0, iOS 15.0, visionOS 1.0, tvOS 16.0, *)
extension SnapAuth: ASAuthorizationControllerDelegate {

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
//        if case ASAuthorizationError.canceled = error {
//        }
        // TODO: don't bubble this up if it's from an autofill request
        if let asError = error as? ASAuthorizationError {
//            asError.code == .canceled


            logger.error("ASACD \(asError.errorCode)")
            // 1001 = no credentials available
//        case unknown = 1000
//        case canceled = 1001
//        case invalidResponse = 1002
//        case notHandled = 1003
//        case failed = 1004
//        case notInteractive = 1005
        }
        logger.error("ASACD fail: \(error)")
        // (lldb) po error
        // Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004 "Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app" UserInfo={NSLocalizedFailureReason=Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app}
        // (lldb) po error.localizedDescription
        // "The operation couldn’t be completed. Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app"

        // The start call can SILENTLY produce this error which never makes it into this handler
        // ASAuthorizationController credential request failed with error: Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004 "(null)"

        Task {
            if (state == .authenticating) {
                await delegate?.snapAuth(didFinishAuthentication: .failure(.asAuthorizationError))
            } else if (state == .registering) {
                await delegate?.snapAuth(didFinishRegistration: .failure(.asAuthorizationError))
            } else if (state == .autofill) {
                // Intentional no-op
            }

            state = .idle
        }
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if delegate == nil {
            logger.error("No SnapAuth delegate set")
            return
        }
        logger.debug("ASACD did complete")


        switch authorization.credential {
        case is ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.debug("switch passkey assn")
            handleAssertion(authorization.credential as! ASAuthorizationPlatformPublicKeyCredentialAssertion)
        case is ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.debug("switch passkey registration")
            handleRegistration(authorization.credential as! ASAuthorizationPlatformPublicKeyCredentialRegistration)
#if HARDWARE_KEY_SUPPORT
        case is ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
            logger.debug("switch hardware key registration")
            handleRegistration(authorization.credential as! ASAuthorizationSecurityKeyPublicKeyCredentialRegistration)
        case is ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            logger.debug("switch hardware key assn")
            handleAssertion(authorization.credential as! ASAuthorizationSecurityKeyPublicKeyCredentialAssertion)
#endif
        default:
            // TODO: Handle this properly
            logger.error("uhh")
        }
    }

    private func handleRegistration(
        _ registration: ASAuthorizationPublicKeyCredentialRegistration
    ) {
        // Decode, send to SA, hand back resposne via delegate method
        logger.info("got a registratoin response")

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
            logger.error("No attestation")
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
            let tokenResponse = await api.makeRequest(
                path: "/registration/process",
                body: body,
                type: SAProcessAuthResponse.self)
            guard tokenResponse != nil else {
                logger.debug("no/invalid process response")
                // TODO: delegate failure (network error?)
                return
            }
            guard tokenResponse!.result != nil else {
                // TODO: bubble this up
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthTokenInfo(
                token: tokenResponse!.result!.token,
                expiresAt: tokenResponse!.result!.expiresAt)

            await delegate?.snapAuth(didFinishRegistration: .success(rewrapped))
        }
    }

    private func handleAssertion(
        _ assertion: ASAuthorizationPublicKeyCredentialAssertion
    ) {

        // This can (will always?) be `nil` when using, at least, a hardware key
        let userHandle = assertion.userID != nil
            ? Base64URL(from: assertion.userID)
            : nil

        // If userHandle is nil, guard that we have userInfo since it's required on the BE


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
            let tokenResponse = await api.makeRequest(
                path: "/auth/process",
                body: body,
                type: SAProcessAuthResponse.self)
            guard tokenResponse != nil else {
                logger.debug("no/invalid process response")
                // TODO: delegate failure (network error?)
                return
            }
            guard tokenResponse!.result != nil else {
                // TODO: bubble this up
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthTokenInfo(
                token: tokenResponse!.result!.token,
                expiresAt: tokenResponse!.result!.expiresAt)

            await delegate?.snapAuth(didFinishAuthentication: .success(rewrapped))
        }

    }
// tvOS only? Probably not needed.
//    public func authorizationController(_ controller: ASAuthorizationController, didCompleteWithCustomMethod method: ASAuthorizationCustomMethod) {
//        if method == .other {
//
//        }
//    }
}

