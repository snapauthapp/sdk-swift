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
        keyTypes: [SnapAuth.KeyType]) -> [ASAuthorizationRequest] {
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
}
