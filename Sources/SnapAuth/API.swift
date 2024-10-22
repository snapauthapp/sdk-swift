import Foundation

/// Wrapper that matches the API wire format
///
/// Network calls (non-broken) will return the result and 0 or more errors on response, or null and one or more errors on error
// FIXME: this is not strictly correct
struct SAWrappedResponse<T>: Decodable where T: Decodable {
    let result: T?
    let errors: [SAApiError]?

    struct SAApiError: Decodable {
        let code: String
        let message: String
    }
}

struct SACreateRegisterOptionsRequest: Encodable {
    let user: AuthenticatingUser?
}
struct SACreateRegisterOptionsResponse: Decodable {
    let publicKey: PublicKeyOptions

    struct PublicKeyOptions: Decodable {
        let rp: RPInfo
        let user: UserInfo
        let challenge: Base64URL
        // let pubKeyCredParams: ['type' => 'public-key', 'alg' => Int][]
        // timeout: Int
        let attestation: Attestation
        // authenticatorSelection is a mess

        struct RPInfo: Decodable {
            let id: String
            let name: String
        }
        struct UserInfo: Decodable {
            let id: Base64URL
        }
    }
}

struct SAProcessRegisterRequest: Encodable {
    let credential: RegCredential

    // See WebAuthn RegistrationResponseJSON format
    struct RegCredential: Encodable {
        let type: String = "public-key"
        let rawId: Base64URL
        let response: RegResponse
        // authenticatorAttachment
        // clientExtensionResults
        struct RegResponse: Encodable {
            let clientDataJSON: Base64URL
            let attestationObject: Base64URL
            let transports: [Transport]
        }
    }
}


enum Attestation: String, Decodable {
    case none
    case indirect
    case direct
    case enterprise
}


enum Transport: String, Encodable {
    case ble
    case smartCard = "smart-card"
    case hybrid
    case `internal`
    case nfc
    case usb

    /*
    private typealias ASTransport = ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport

    init(from asFormat: ASTransport) {
        switch asFormat {
        case ASTransport.bluetooth:
            self = .ble
        case ASTransport.nfc:
            self = .nfc
        case ASTransport.usb:
            self = .usb
        }
    }
     */
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
    let user: AuthenticatingUser?
    // See WebAuthn AuthenticationResponseJSON format
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
