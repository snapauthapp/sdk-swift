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

        sendError(.unknown)
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
//        if delegate == nil {
//            logger.error("No SnapAuth delegate set")
//            return
//        }
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

    /// Sends the error to the appropriate delegate method and resets the internal state back to idle
    private func sendError(_ error: SnapAuthError) {
        switch state {
        case .authenticating:
            authContinuation?.resume(returning: .failure(error))
//            Task { await delegate?.snapAuth(didFinishAuthentication: .failure(error)) }
        case .registering:
//            Task { await delegate?.snapAuth(didFinishRegistration: .failure(error)) }
            registerContinuation?.resume(returning: .failure(error))
        case .idle:
            logger.error("Tried to send error in idle state")
        case .autofill:
            // No-op for now
            break
        }
        state = .idle
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
            // This may change in the future?
            logger.error("No attestation in registration response")
            registerContinuation?.resume(returning: .failure(.registrationDataMissing))
//            sendError(.registrationDataMissing)
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
                path: "/registration/process",
                body: body,
                type: SAProcessAuthResponse.self)
            guard case let .success(processAuth) = response else {
                logger.debug("/registration/process error")
//                await delegate?.snapAuth(didFinishRegistration: .failure(response.getError()!))
                registerContinuation?.resume(returning: .failure(response.getError()!))
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthTokenInfo(
                token: processAuth.token,
                expiresAt: processAuth.expiresAt)

            registerContinuation?.resume(returning: .success(rewrapped))
//            await delegate?.snapAuth(didFinishRegistration: .success(rewrapped))
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
            let response = await api.makeRequest(
                path: "/auth/process",
                body: body,
                type: SAProcessAuthResponse.self)
            guard case let .success(authResponse) = response else {
                logger.debug("/auth/process error")
//                await delegate?.snapAuth(didFinishAuthentication: .failure(response.getError()!))
                authContinuation?.resume(returning: .failure(response.getError()!))
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthTokenInfo(
                token: authResponse.token,
                expiresAt: authResponse.expiresAt)

            authContinuation?.resume(returning: .success(rewrapped))
//            await delegate?.snapAuth(didFinishAuthentication: .success(rewrapped))
        }

    }
// tvOS only? Probably not needed.
//    public func authorizationController(_ controller: ASAuthorizationController, didCompleteWithCustomMethod method: ASAuthorizationCustomMethod) {
//        if method == .other {
//
//        }
//    }
}

