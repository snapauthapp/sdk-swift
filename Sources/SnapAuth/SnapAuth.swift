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

    private let api: SnapAuthClient

    private let logger: Logger

    public var delegate: SnapAuthDelegate?

    public var presentationContextProvider: ASWebAuthenticationPresentationContextProviding?


    private var anchor: ASPresentationAnchor?

    private var authController: ASAuthorizationController?

    public init(
       publishableKey: String,
       urlBase: URL = URL(string: "https://api.snapauth.app")!
     ) {
        logger = Logger()
        api = SnapAuthClient(
            urlBase: urlBase,
            publishableKey: publishableKey,
            logger: logger)
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
    public func handleAutofill() async {
        await handleAutofill(anchor: ASPresentationAnchor())
    }

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
        if #available(iOS 16.0, *) {
            cancelAutoFillAssistedPasskeySignIn()
        }
    }

    /**
     TODO: figure out how to cancel this request when modal begins
     */
    @available(iOS 16.0, *)
    public func handleAutofill(presentationContextProvider: ASAuthorizationControllerPresentationContextProviding) async {
        reset()
        logger.debug("AF PCP start")
        let parsed = await api.makeRequest(
            path: "/auth/createOptions",
            body: [:] as [String:String],
            type: SACreateAuthOptionsResponse.self)!

        let challenge = parsed.result.publicKey.challenge.toData()!
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: parsed.result.publicKey.rpId)
        let request = provider.createCredentialAssertionRequest(
            challenge: challenge)


        let controller = ASAuthorizationController(authorizationRequests: [request])
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = presentationContextProvider
        logger.debug("AF perform")
        controller.performAutoFillAssistedRequests()
    }

    @available(iOS 16.0, *)
    func cancelAutoFillAssistedPasskeySignIn() {
        logger.debug("cancel AF")
        if authController != nil {
           authController!.cancel()
           authController = nil
         }
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

        let body = ["user": user]

        let parsed = await api.makeRequest(
            path: "/auth/createOptions",
            body: body,
            type: SACreateAuthOptionsResponse.self)!

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
        authController = controller
        logger.debug("setting delegate")
        controller.delegate = self
        controller.presentationContextProvider = self
        logger.debug("perform requests")
        controller.performRequests()
        logger.debug("performed requests")

        // Sometimes the controller just WILL NOT CALL EITHER DELEGATE METHOD, so... yeah.
        // Maybe start a timer and auto-fail if neither delegate method runs in time?

    }
}

@available(macOS 12.0, iOS 15.0, *)
extension SnapAuth: ASAuthorizationControllerDelegate {

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        // TODO: don't bubble this up if it's from an autofill request
        if let asError = error as? ASAuthorizationError {
//            asError.code == .canceled


            logger.error("ASACD \(asError.errorCode)")
        }
        logger.error("ASACD fail: \(error)")
        // (lldb) po error
        // Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004 "Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app" UserInfo={NSLocalizedFailureReason=Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app}
        // (lldb) po error.localizedDescription
        // "The operation couldn’t be completed. Application with identifier V46X94865S.app.snapauth.PassKeyExample is not associated with domain demo.snapauth.app"

        // The start call can SILENTLY produce this error which never makes it into this handler
        // ASAuthorizationController credential request failed with error: Error Domain=com.apple.AuthenticationServices.AuthorizationError Code=1004 "(null)"

        Task {
            // Failure reason, etc, etc
//            await delegate?.snapAuth(didAuthenticate: .failure)
            await delegate?.snapAuth(didFinishAuthentication: .failure(.asAuthorizationError))
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
            let tokenResponse = await api.makeRequest(
                path: "/auth/process",
                body: body,
                type: SAProcessAuthResponse.self)
            if tokenResponse == nil {
                logger.debug("no/invalid process response")
                /// TODO: delegate failure (network error?)
                return
            }
            logger.debug("got token response")
            let rewrapped = SnapAuthAuth(
                token: tokenResponse!.result.token,
                expiresAt: tokenResponse!.result.expiresAt)

            await delegate?.snapAuth(didFinishAuthentication: .success(rewrapped))

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
