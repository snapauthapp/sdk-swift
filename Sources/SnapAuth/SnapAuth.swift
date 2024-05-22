import AuthenticationServices
import Foundation
import os

/// The SnapAuth SDK.
///
/// This is used to start the passkey registration and authentication processes,
/// typically in the `action` of a `Button`
@available(macOS 12.0, iOS 15.0, tvOS 16.0, *)
public class SnapAuth: NSObject { // NSObject for ASAuthorizationControllerDelegate

    /// The delegate that SnapAuth informs about the success or failure of an operation.
    public var delegate: SnapAuthDelegate?

    internal let api: SnapAuthClient

    internal let logger: Logger

    // TODO: weak (all of these)?
    internal var presentationContextProvider: ASAuthorizationControllerPresentationContextProviding?

    internal var anchor: ASPresentationAnchor?

    internal var authController: ASAuthorizationController?

    /// - Parameters:
    ///   - publishableKey: Your SnapAuth publishable key. This can be obtained
    ///   from the [SnapAuth dashboard](https://dashboard.snapauth.app)
    ///   - urlBase: A custom URL base for the SnapAuth API. This is generally
    ///   for internal use.
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

    /// Permitted authenticator types
    public enum Authenticator: CaseIterable {
        /// Allow all available authenticator types to be used
        public static let all = Set(Authenticator.allCases)

        /// Prompt for passkeys.
        case passkey

        #if HARDWARE_KEY_SUPPORT
        /// Prompt for hardware keys. This is not available on all platforms.
        case securityKey
        #endif
    }

    /// Reinitializes internal state before starting a request.
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

    /// Starts the passkey enrollment process.
    /// Upon completion, the delegate will be called with either success or failure.
    /// - Parameters:
    ///   - name: The name of the user.
    ///   - displayName: The proper name of the user. If omitted, name will be used.
    ///   - authenticators: What authenticators should be permitted. If omitted,
    ///   all available types for the platform will be allowed.
    ///
    /// - Returns: Nothing. Instead, the `SnapAuthDelegate` will be informed of the result.
    public func startRegister(
        name: String,
        displayName: String? = nil,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async {
        await startRegister(
            name: name,
            anchor: .default,
            displayName: displayName,
            authenticators: authenticators)
    }

    // TODO: Only make this public if needed?
    internal func startRegister(
        name: String,
        anchor: ASPresentationAnchor,
        displayName: String? = nil,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async {
        reset()
        self.anchor = anchor
        state = .registering

        let body = SACreateRegisterOptionsRequest(user: nil)
        let response = await api.makeRequest(
            path: "/registration/createOptions",
            body: body,
            type: SACreateRegisterOptionsResponse.self)

        guard case let .success(options) = response else {
            let error = response.getError()!
            await delegate?.snapAuth(didFinishRegistration: .failure(error))
            return
        }

        let authRequests = buildRegisterRequests(
            from: options,
            name: name,
            displayName: displayName,
            authenticators: authenticators)


        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        logger.debug("SR perform")
        controller.performRequests()
    }

    internal var authenticatingUser: AuthenticatingUser?

    /// Starts the authentication process.
    /// Upon completion, the delegate will be called with either success or failure.
    ///
    /// - Parameters:
    ///   - user: The authenticating user's `id` or `handle`
    ///   - authenticators: What authenticators should be permitted. If omitted, all available types for the platform will be allowed.
    ///
    /// - Returns: Nothing. Instead, the `SnapAuthDelegate` will be informed of the result.
    public func startAuth(
        _ user: AuthenticatingUser,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async {
        await startAuth(user, anchor: .default, authenticators: authenticators)
    }

    /// This may be exposed publicly if the default anchor proves insufficient
    internal func startAuth(
        _ user: AuthenticatingUser,
        anchor: ASPresentationAnchor,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async {
        reset()
        self.anchor = anchor
        self.authenticatingUser = user
        state = .authenticating

        let body = ["user": user]

        let response = await api.makeRequest(
            path: "/auth/createOptions",
            body: body,
            type: SACreateAuthOptionsResponse.self)


        guard case let .success(options) = response else {
            let error = response.getError()!
            await delegate?.snapAuth(didFinishAuthentication: .failure(error))
            return
        }

        logger.debug("before controller")
        let authRequests = buildAuthRequests(
            from: options,
            authenticators: authenticators)

        // Set up the native controller and start the request(s).
        // The UI should show the sheet to use a passkey or security key
        let controller = ASAuthorizationController(authorizationRequests: authRequests)
        authController = controller
        controller.delegate = self
        controller.presentationContextProvider = self
        logger.debug("perform requests")
        controller.performRequests()
        logger.debug("performed requests")

        // Sometimes the controller just WILL NOT CALL EITHER DELEGATE METHOD, so... yeah.
        // Maybe start a timer and auto-fail if neither delegate method runs in time?
    }

    internal var state: State = .idle
}

/// SDK state
///
/// This helps with sending appropriate failure messages back to delegates,
/// since all AS delegate failure paths go to a single place.
enum State {
    case idle
    case registering
    case authenticating
    case autofill
}

public enum AuthenticatingUser {
    /// Your application's internal identifier for the user (usually a primary key)
    case id(String)
    /// The user's handle, such as a username or email address
    case handle(String)
}

/// Encode as JSON to either `{"id": id}` or `{"handle": handle}`, which is what the SnapAuth APIs need
extension AuthenticatingUser: Encodable {
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

/// Small addition to the native Result type to more easily extract error details.
extension Result {
    func getError() -> Failure? {
        switch self {
        case .success:
            return nil
        case .failure(let failure):
            return failure
        }
    }
}
