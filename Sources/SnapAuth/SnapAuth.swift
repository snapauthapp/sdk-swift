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


Known issues:
 - tvOS will not present any dialog, full stop
 - autofill will not start

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

        /// Prompt for passkeys
        case passkey

        #if HARDWARE_KEY_SUPPORT
        /// Prompt for hardware keys. This is not available on all platforms
        case securityKey

        /// Allow all available authenticator types to be used
        public static let all: Set<KeyType> = [.passkey, .securityKey]
        #else
        /// Allow all available authenticator types to be used
        public static let all: Set<KeyType> = [.passkey]
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
        keyTypes: Set<KeyType> = KeyType.all
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

    internal var authenticatingUser: SAUser?
    /*
     TODO: this should take a new UserInfo
     */
    public func startAuth(
        _ user: SAUser,
        anchor: ASPresentationAnchor,
        keyTypes: Set<KeyType> = KeyType.all
    ) async {
        reset()
        self.anchor = anchor
        self.authenticatingUser = user

        let body = ["user": user]

        let parsed = await api.makeRequest(
            path: "/auth/createOptions",
            body: body,
            type: SACreateAuthOptionsResponse.self)!


        logger.debug("before controller")


        let authRequests = buildAuthRequests(from: parsed.result, keyTypes: keyTypes)

        // Set up the native controller and start the request(s).
        // The UI should show the sheet to use a passkey or security key
        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        logger.debug("setting delegate")
        controller.delegate = self
        logger.debug("setting presentation context")
        controller.presentationContextProvider = self
        logger.debug("perform requests")
        controller.performRequests()
        logger.debug("performed requests")

        // Sometimes the controller just WILL NOT CALL EITHER DELEGATE METHOD, so... yeah.
        // Maybe start a timer and auto-fail if neither delegate method runs in time?

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
