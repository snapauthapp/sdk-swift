import AuthenticationServices

@available(macOS 12.0, iOS 15.0, tvOS 16.0, *)
extension SnapAuth {
    internal func buildRegisterRequests(
        from options: SACreateRegisterOptionsResponse,
        username: String,
        displayName: String?,
        authenticators: Set<SnapAuth.Authenticator>
    ) -> [ASAuthorizationRequest] {
        let challenge = options.publicKey.challenge.data
        var requests: [ASAuthorizationRequest] = []

        if authenticators.contains(.passkey) {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rp.id)
            let request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: username,
                userID: options.publicKey.user.id.data)

            requests.append(request)
        }

#if HARDWARE_KEY_SUPPORT
        if authenticators.contains(.securityKey) {
            let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rp.id)
            let request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                displayName: displayName ?? username,
                name: username,
                userID: options.publicKey.user.id.data)
            request.attestationPreference = .direct // TODO: use API response
            request.credentialParameters = [.init(algorithm: .ES256)] // TODO: use API response

            requests.append(request)
        }
#endif

        return requests
    }

    internal func buildAuthRequests(
        from options: SACreateAuthOptionsResponse,
        authenticators: Set<SnapAuth.Authenticator>
    ) -> [ASAuthorizationRequest] {
        let challenge = options.publicKey.challenge.data

        var requests: [ASAuthorizationRequest] = []

        if authenticators.contains(.passkey) {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rpId)

            // Process the `allowedCredentials` so the authenticator knows what
            // it can use. API responses omit this for AutoFill requests.
            let allowed = options.publicKey.allowCredentials?.map {
                ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id.data)
            }

            let request = provider.createCredentialAssertionRequest(challenge: challenge)
            if allowed != nil {
                request.allowedCredentials = allowed!
            }
            requests.append(request)
        }

#if HARDWARE_KEY_SUPPORT
        if authenticators.contains(.securityKey) &&
           options.publicKey.allowCredentials != nil {

            let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rpId)
            let request = provider.createCredentialAssertionRequest(challenge: challenge)
            let allowed = options.publicKey.allowCredentials!.map {
                ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                    credentialID: $0.id.data,
                    transports: ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported) // TODO: the API should hint this
            }
            request.allowedCredentials = allowed
            requests.append(request)
        }
#endif
        return requests
    }
}
