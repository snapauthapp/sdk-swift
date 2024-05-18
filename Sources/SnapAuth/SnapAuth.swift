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
@available(macOS 12.0, iOS 15.0, tvOS 16.0, *)
public class SnapAuth: NSObject { // NSObject for ASAuthorizationControllerDelegate

    internal let api: SnapAuthClient

    internal let logger: Logger

    public var delegate: SnapAuthDelegate?

    public var presentationContextProvider: ASAuthorizationControllerPresentationContextProviding?


    internal var anchor: ASPresentationAnchor?

    internal var authController: ASAuthorizationController?

    public init(
       publishableKey: String,
       urlBase: URL = URL(string: "https://api.snapauth.app")!
    ) {
        logger = Logger(subsystem: "SnapAuth", category: "SA Cat")
        api = SnapAuthClient(
            urlBase: urlBase,
            publishableKey: publishableKey,
            logger: logger)
    }

    public enum KeyType {
        /// Allow all available authenticator types to be used
        public static let all: [KeyType] = [.passkey, .securityKey]

        /// Prompt for passkeys
        case passkey

        #if !os(tvOS) && !os(visionOS)
        /// Prompt for hardware keys. This is not available on all platforms
        case securityKey
        #endif
    }

    /**
     Reinitializes internal state before starting a request.
     */
    internal func reset() -> Void {
        self.authenticatingUser = nil
        cancelPendingRequest()
    }

    private func cancelPendingRequest() {
        logger.debug("Canceling pending requests")
        if authController != nil {
            #if !os(tvOS)
            if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *) {
                authController!.cancel()
            }
            #endif
            authController = nil
        }
    }

    public func startRegister(
        name: String,
        anchor: ASPresentationAnchor,
        displayName: String? = nil,
        keyTypes: [KeyType] = KeyType.all
    ) async {
        reset()
        self.anchor = anchor

        let body = SACreateRegisterOptionsRequest(user: nil)
        let options = await api.makeRequest(
            path: "/registration/createOptions",
            body: body,
            type: SACreateRegisterOptionsResponse.self)!


        let authRequests = buildRegisterRequests(
            from: options.result,
            name: name,
            displayName: displayName,
            keyTypes: keyTypes)


        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        logger.debug("SR perform")
        controller.performRequests()
    }

    private var authenticatingUser: SAUser?
    /**
     TODO: this should take a new UserInfo
     */
    public func startAuth(_ user: SAUser, anchor: ASPresentationAnchor, keyTypes: [KeyType] = KeyType.all) async {
        reset()
        self.anchor = anchor
        self.authenticatingUser = user

        let body = ["user": user]

        let parsed = await api.makeRequest(
            path: "/auth/createOptions",
            body: body,
            type: SACreateAuthOptionsResponse.self)!


        logger.debug("before controller")


        /// TODO: look at providers to fill in `requests`
        let authRequests = buildAuthRequests(from: parsed.result)

        /// Set up the native controller and start the request(s).
        /// The UI should show the sheet to use a passkey or security key
        let controller = ASAuthorizationController(authorizationRequests: authRequests)
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

@available(macOS 12.0, iOS 15.0, visionOS 1.0, tvOS 16.0, *)
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
            handleAssertion(authorization.credential as! ASAuthorizationSecurityKeyPublicKeyCredentialAssertion)
        case is ASAuthorizationPlatformPublicKeyCredentialAssertion:
            logger.debug("switch passkey assn")
            handleAssertion(authorization.credential as! ASAuthorizationPlatformPublicKeyCredentialAssertion)
        case is ASAuthorizationPlatformPublicKeyCredentialRegistration:
            logger.debug("switch passkey registration")
            handleRegistration(authorization.credential as! ASAuthorizationPlatformPublicKeyCredentialRegistration)
        case is ASAuthorizationSecurityKeyPublicKeyCredentialRegistration:
            logger.debug("switch hardware key registration")
            handleRegistration(authorization.credential as! ASAuthorizationSecurityKeyPublicKeyCredentialRegistration)
        default:
            logger.error("uhh")
        }
        /// TODO: registration support in here as well - ASAuthorization uses the same callback
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
            logger.error("No attestation")
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
            let tokenResponse = await api.makeRequest(
                path: "/registration/process",
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

            await delegate?.snapAuth(didFinishRegistration: .success(rewrapped))
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


@available(macOS 12.0, iOS 15.0, tvOS 16.0, visionOS 1.0, *)
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
