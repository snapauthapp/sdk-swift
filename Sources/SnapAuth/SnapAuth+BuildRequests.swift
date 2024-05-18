//
//  File.swift
//  
//
//  Created by Eric Stern on 5/17/24.
//

import AuthenticationServices

//import Foundation

extension SnapAuth {
    internal func buildRegisterRequests(
        from options: SACreateRegisterOptionsResponse,
        name: String,
        displayName: String?,
        keyTypes: [SnapAuth.KeyType]
    ) -> [ASAuthorizationRequest] {
        let challenge = options.publicKey.challenge.toData()!

        // Passkeys
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.publicKey.rp.id)
        let request = provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: name,
            userID: options.publicKey.user.id.toData()!)

        /// TODO: filter tvOS+visionOS AND based on attn pref
        // Hardware keys
        let hwProvider = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.publicKey.rp.id)
        let hwRequest = hwProvider.createCredentialRegistrationRequest(
            challenge: challenge,
            displayName: name, 
            name: name,
            userID: options.publicKey.user.id.toData()!)
        hwRequest.attestationPreference = .direct // TODO: API
        hwRequest.credentialParameters = [.init(algorithm: .ES256)] // TODO: API

        return [request, hwRequest]
    }

    internal func buildAuthRequests(
        from options: SACreateAuthOptionsResponse
    ) -> [ASAuthorizationRequest] {
        // https://developer.apple.com/videos/play/wwdc2022/10092/ ~ 12:05

        let challenge = options.publicKey.challenge.toData()!

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.publicKey.rpId)

        /// Process the `allowedCredentials` so the authenticator knows what it can use
        let allowed = options.publicKey.allowCredentials!.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id.toData()!)
        }


        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.allowedCredentials = allowed


        let p2 = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: options.publicKey.rpId)
        let r2 = p2.createCredentialAssertionRequest(challenge: challenge)
        let a2 = options.publicKey.allowCredentials!.map {
            ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                credentialID: $0.id.toData()!,
                transports: ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported) /// TODO: the API should hint this
        }
        r2.allowedCredentials = a2

        return [request, r2]
    }
}
