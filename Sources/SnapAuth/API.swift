import Foundation

/**
 Wrapper that matches the API wire format

 Network calls (non-broken) will return the result and 0 or more errors on response, or null and one or more errors on error

 */
struct SAWrappedResponse<T>: Decodable where T: Decodable {
    let result: T
}




struct SACreateAuthOptionsResponse: Decodable {
    let publicKey: PublicKeyOptions
    // mediation

    struct PublicKeyOptions: Decodable {

        struct AllowCredential: Decodable {
            let type: String // == "public-key"
            let id: Base64URL
            // transports?
        }

        let rpId: String
        let challenge: Base64URL
        let allowCredentials: [AllowCredential]?
    }
}

struct SAProcessAuthRequest: Encodable {
    // user ~ id/handle (skip for now since this is passkey only flow...ish)
    let credential: SACredential
    let user: SAUser?
    struct SACredential: Codable {
        let type: String = "public-key"
        let rawId: Base64URL
        let response: SACredential.Response
        struct Response: Codable {
            let authenticatorData: Base64URL
            let clientDataJSON: Base64URL
            let signature: Base64URL
            let userHandle: Base64URL?
        }
    }

}

struct SAProcessAuthResponse: Decodable {
    let token: String
    let expiresAt: Date
}
