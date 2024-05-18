import AuthenticationServices

@available(macOS 12.0, iOS 15.0, tvOS 16.0, *)
extension SnapAuth {
    internal func buildRegisterRequests(
        from options: SACreateRegisterOptionsResponse,
        name: String,
        displayName: String?,
        keyTypes: Set<SnapAuth.KeyType>
    ) -> [ASAuthorizationRequest] {
        let challenge = options.publicKey.challenge.toData()!

        var requests: [ASAuthorizationRequest] = []

        if keyTypes.contains(.passkey) {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rp.id)
            let request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                name: name,
                userID: options.publicKey.user.id.toData()!)

            requests.append(request)
        }

#if HARDWARE_KEY_SUPPORT
        if keyTypes.contains(.securityKey) {
            let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rp.id)
            let request = provider.createCredentialRegistrationRequest(
                challenge: challenge,
                displayName: name,
                name: name,
                userID: options.publicKey.user.id.toData()!)
            request.attestationPreference = .direct // TODO: use API response
            request.credentialParameters = [.init(algorithm: .ES256)] // TODO: use API response

            requests.append(request)
        }
#endif

        return requests
    }

    internal func buildAuthRequests(
        from options: SACreateAuthOptionsResponse,
        keyTypes: Set<SnapAuth.KeyType>
    ) -> [ASAuthorizationRequest] {
        // https://developer.apple.com/videos/play/wwdc2022/10092/ ~ 12:05

        let challenge = options.publicKey.challenge.toData()!

        var requests: [ASAuthorizationRequest] = []

        if keyTypes.contains(.passkey) {
            let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rpId)

            /// Process the `allowedCredentials` so the authenticator knows what it can use
            let allowed = options.publicKey.allowCredentials!.map {
                ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id.toData()!)
            }

            let request = provider.createCredentialAssertionRequest(challenge: challenge)
            request.allowedCredentials = allowed
            requests.append(request)
        }

#if HARDWARE_KEY_SUPPORT
        if keyTypes.contains(.securityKey) {

            let provider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
                relyingPartyIdentifier: options.publicKey.rpId)
            let request = provider.createCredentialAssertionRequest(challenge: challenge)
            let allowed = options.publicKey.allowCredentials!.map {
                ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                    credentialID: $0.id.toData()!,
                    transports: ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported) // TODO: the API should hint this
            }
            request.allowedCredentials = allowed
            requests.append(request)
        }
#endif
        return requests
    }
}
