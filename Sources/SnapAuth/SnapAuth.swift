//
//  SnapAuth.swift
//  PassKeyExample
//
//  Created by Eric Stern on 3/15/24.
//

import Foundation
import os // logger
import AuthenticationServices

/**
 Resources:
 - https://developer.apple.com/videos/play/wwdc2021/10106/
 - https://developer.apple.com/videos/play/wwdc2022/10092/
 */

/**
 Related setup for SnapAuth:

 The app MUST have an Associated Domains entitlement configured
 1) add `webcredentials:yourrpid.com` into the list
    1) This must match the RP ID displayed on SnapAuth for your API key
    2) You MAY amend `?mode=developer` to the value. If so, you MUST turn on SWC Developer Mode: `sudo swcutil developer-mode -e 1` (https://forums.developer.apple.com/forums/thread/743890)
 2) Associated Domains only works with a paid developer account, and possibly only one on a team (with DUNS number, etc.)
  It is restricted from use on free accounts, which is outside of our control
 3) The domain must have a corresponding Associated Domains file: https://developer.apple.com/documentation/xcode/supporting-associated-domains
    1) https://yourdomain.com/.well-known/apple-app-site-association must exist
    2) It must serve valid JSON with association data
    3) `.webcredentials.apps.[]` must exist and contain your app identifier (you may need to go into the developer portal to get this. It may contain multiple apps


 */
@available(macOS 12.0, iOS 15.0, *)
public class SnapAuth: NSObject { // NSObject for ASAuthorizationControllerDelegate
    private let publishableKey: String
    private let urlBase: URL

    private let logger: Logger

    public var delegate: SnapAuthDelegate?

    public var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?


    private var anchor: ASPresentationAnchor?

    public init(publishableKey: String,
//         delegate: SnapAuthDelegate,
         urlBase: URL = URL(string: "https://api.snapauth.app")!
    ) {
        self.publishableKey = publishableKey
//        self.delegate = delegate
        self.urlBase = urlBase
        self.logger = Logger()
    }

    public enum Providers {
        /// Allow passkeys and hardware keys
        case all
        /// Only prompt for passkeys
        case passkeyOnly
        /// Only prompt for hardware keys
        case securityKeyOnly
    }

    // TODO, determine other platforms
    #if os(iOS)
    @available(iOS 16.0, *)
    public func handleAutofill(anchor: ASPresentationAnchor) async {
        self.anchor = anchor

        await handleAutofill(presentationContextProvider: self)
    }

    /**
     Reinitializes internal state before starting a request.
     */
    private func reset() -> Void {
//        self.anchor = nil
        self.authenticatingUser = nil
    }

    /**
     TODO: figure out how to cancel this request when modal begins
     */
    @available(iOS 16.0, *)
    public func handleAutofill(presentationContextProvider: ASAuthorizationControllerPresentationContextProviding) async {
        reset()
        logger.debug("AF start")
        let parsed = await makeRequest(
            path: "/auth/createOptions",
            body: ["ignore":"me"],
            type: SACreateAuthOptions.self)!

        let challenge = parsed.result.publicKey.challenge.toData()!
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: parsed.result.publicKey.rpId)
        let request = provider.createCredentialAssertionRequest(challenge: challenge)


        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = presentationContextProvider
        logger.debug("AF perform")
        controller.performAutoFillAssistedRequests()
    }
    #endif

    private var authenticatingUser: SAUser?
    /**
     TODO: this should take a new UserInfo
     */
    public func startAuth(_ user: SAUser, anchor: ASPresentationAnchor, providers: Providers = .all) async {
        reset()
        self.anchor = anchor
        self.authenticatingUser = user

        let body: [String: [String: String]]
        switch user {
        case .id(let id):
            body = ["user": ["id": id]]
        case .handle(let handle):
            body = ["user": ["handle": handle]]
        }

        let parsed = await makeRequest(
            path: "/auth/createOptions",
            body: body,
            type: SACreateAuthOptions.self)!

//        logger.debug("parsed ok")
//        logger.debug("\(parsed.result.publicKey.challenge)")

        // https://developer.apple.com/videos/play/wwdc2022/10092/ ~ 12:05

        let challenge = parsed.result.publicKey.challenge.toData()!

        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: parsed.result.publicKey.rpId)

        /// Process the `allowedCredentials` so the authenticator knows what it can use
        let allowed = parsed.result.publicKey.allowCredentials!.map {
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: $0.id.toData()!)
        }


        //        logger.debug("RP: \(parsed.result.publicKey.rpId)")
        let request = provider.createCredentialAssertionRequest(challenge: challenge)
        request.allowedCredentials = allowed


        // this works, will need to decode differently
        let p2 = ASAuthorizationSecurityKeyPublicKeyCredentialProvider(
            relyingPartyIdentifier: parsed.result.publicKey.rpId)
        let r2 = p2.createCredentialAssertionRequest(challenge: challenge)
        let a2 = parsed.result.publicKey.allowCredentials!.map {
            ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor(
                credentialID: $0.id.toData()!,
                transports: ASAuthorizationSecurityKeyPublicKeyCredentialDescriptor.Transport.allSupported) /// TODO: the API should hint this
        }
        r2.allowedCredentials = a2
        logger.debug("before controller")


        /// TODO: look at providers to fill in `requests`

        /// Set up the native controller and start the request(s).
        /// The UI should show the sheet to use a passkey or security key
        let controller = ASAuthorizationController(authorizationRequests: [request, r2]) // + r2
        logger.debug("setting delegate")
        controller.delegate = self
        controller.presentationContextProvider = self
        logger.debug("perform requests")
        controller.performRequests()
        logger.debug("performed requests")

        // Sometimes the controller just WILL NOT CALL EITHER DELEGATE METHOD, so... yeah.
        // Maybe start a timer and auto-fail if neither delegate method runs in time?

    }

    /// Internal API call wrapper
    private func makeRequest<T>(path: String, body: Encodable, type: T.Type) async -> SAResponse<T>? {
        let url = urlBase.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(basic, forHTTPHeaderField: "Authorization")
        let json = try! JSONEncoder().encode(body)
        request.httpBody = json
        logger.debug("--> \(String(decoding: json, as: UTF8.self))")

        let (data, response) = try! await URLSession.shared.data(for: request)
        let jsonString = String(data: data, encoding: .utf8)
        logger.debug("<-- \(jsonString ?? "not a string")")

        guard let parsed = try? JSONDecoder().decode(SAResponse<T>.self, from: data) else {
            logger.error("nope")
            return nil
        }

        return parsed
    }

    /// Auth header generation
    var basic: String {
        return "Basic " + Data("\(publishableKey):".utf8).base64EncodedString()
    }

}

@available(macOS 12.0, iOS 15.0, *)
extension SnapAuth: ASAuthorizationControllerDelegate {

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        logger.error("ASACD fail: \(error)")
        // (lldb) po error
        // Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004 "Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app" UserInfo={NSLocalizedFailureReason=Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app}
        // (lldb) po error.localizedDescription
        // "The operation couldn’t be completed. Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app"

        Task {
            // Failure reason, etc, etc
            await delegate?.snapAuth(didAuthenticate: .failure)
        }
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        logger.debug("ASACD did complete")


        switch authorization.credential {
        case is ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            logger.debug("switch hardware key assn")
        case is ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.debug("switch passkey assn")
        case is ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.debug("switch passkey registration")
        case is ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            logger.debug("switch hardware key registration")
        default:
            logger.debug("uhh")
        }

        /// TODO: registration support in here as well - ASAuthorization uses the same callback

        guard let assertion = authorization.credential as? ASAuthorizationPublicKeyCredentialAssertion else {
            return
        }

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
        let body = SAProcessAuthRequest(credential: cCrd, user: authenticatingUser)
        logger.debug("made a body")
//        logger.debug("user id \(assertion.userID.base64EncodedString())")
        Task {
            let tokenResponse = await makeRequest(path: "/auth/process", body: body, type: SAAuthData.self)
            if tokenResponse == nil {
                logger.debug("no/invalid process response")
                return
            }
            logger.debug("got token response")

            await delegate?.snapAuth(didAuthenticate: .success(tokenResponse!.result))

        }
    }
}


@available(macOS 12.0, iOS 15.0, *)
extension SnapAuth: ASAuthorizationControllerPresentationContextProviding {
    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        logger.debug("presentation anchor")
        return anchor!

        // This almost certainly doesn't work right on iOS and seems to occasionally misbehave on macOS.
        // The SDK should be platform-agnostic... which may mean this is user-configurable?
//        #if os(macOS)
//            return NSApplication.shared.mainWindow ?? ASPresentationAnchor()
//        #else
//            return UIApplication.shared.keyWindow!
//        #endif
    }


}

public enum SAUser {
    case id(String)
    case handle(String)
}
/**
 Encode to either `{"id": id}` or `{"handle": handle}`
 */
extension SAUser: Encodable {
    enum CodingKeys: String, CodingKey {
         case id
         case handle
     }

     public func encode(to encoder: Encoder) throws {
         var container = encoder.container(keyedBy: CodingKeys.self)

         switch self {
         case .id(let value):
             try container.encode(value, forKey: .id)
         case .handle(let value):
             try container.encode(value, forKey: .handle)
         }
     }
}

// just decodable? Also, build this on top of Result<S,E>?
struct SAResponse<T>: Decodable where T: Decodable {
    let result: T
}
struct SACreateAuthOptions: Codable {
    let publicKey: PublicKeyOptions
    // mediation

    struct PublicKeyOptions: Codable {

        struct AllowCredential: Codable {
            let type: String // == "public-key"
            let id: Base64URL
            // transports?
        }

        let rpId: String
        let challenge: Base64URL
        let allowCredentials: [AllowCredential]?
    }
}

public struct SAAuthData {
    public let token: String
    public let expiresAt: Date
}
extension SAAuthData: Decodable {
    // Unixtime needs custom decoding
    enum CodingKeys: CodingKey {
        case token
        case expiresAt
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.token = try container.decode(String.self, forKey: .token)
        let timestamp = try container.decode(Int.self, forKey: .expiresAt)
        expiresAt = Date(timeIntervalSince1970: TimeInterval(timestamp))
//        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
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


public enum SAAuthResponse {
    case success(SAAuthData)
    case failure // TODO: associated data
}


@available(iOS 15.0, *)
public protocol SnapAuthDelegate {
    // optional?
    func snapAuth(didAuthenticate authenticationResponse: SAAuthResponse) async
}
