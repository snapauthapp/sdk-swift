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
        logger.debug("AF start")
        self.anchor = anchor

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
        controller.presentationContextProvider = self
        logger.debug("AF perform")
        controller.performAutoFillAssistedRequests()

    }
    #endif

    /**
     TODO: this should take a new UserInfo
     */
    public func startAuth(_ user: SAUser, anchor: ASPresentationAnchor, providers: Providers = .all) async {
        self.anchor = anchor

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

        let (data, response) = try! await URLSession.shared.data(for: request)
        let jsonString = String(data: data, encoding: .utf8)
        logger.debug("\(jsonString ?? "not a string")")

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

    public func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
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
    public func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        logger.debug("ASACD did complete")


        switch authorization.credential {
        case is ASAuthorizationSecurityKeyPublicKeyCredentialAssertion:
            logger.debug("switch hardware key")
        case is ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.debug("switch passkey")
        default:
            logger.debug("uhh")
        }

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
        let body = SAProcessAuthRequest(credential: cCrd)
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
    // TODO: codable here to simplify generation request?
//    case anonymous
    case id(String)
    case handle(String)
}

// just decodable? Also, build this on top of Result<S,E>?
struct SAResponse<T>: Codable where T: Codable {
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

public struct SAAuthData: Codable {
    public let token: String
    // expiresAt
}

struct SAProcessAuthRequest: Codable {
    // user ~ id/handle (skip for now since this is passkey only flow...ish)
    let credential: SACredential
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
