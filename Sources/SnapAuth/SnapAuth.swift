import AuthenticationServices
import Foundation
import os

/// The SnapAuth SDK.
///
/// This is used to start the passkey registration and authentication processes,
/// typically in the `action` of a `Button`
@available(macOS 12.0, iOS 15.0, tvOS 16.0, *)
public class SnapAuth: NSObject { // NSObject for ASAuthorizationControllerDelegate

    internal let api: SnapAuthClient

    internal let logger: Logger

    // TODO: weak (all of these)?
    internal var presentationContextProvider: ASAuthorizationControllerPresentationContextProviding?

    internal var anchor: ASPresentationAnchor?

    internal var authController: ASAuthorizationController?

    internal var continuation: CheckedContinuation<SnapAuthResult, Never>?

    /// Initialize the SnapAuth SDK
    /// - Parameters:
    ///   - publishableKey: Your SnapAuth publishable key. This can be obtained
    ///   from the [SnapAuth dashboard](https://dashboard.snapauth.app)
    ///   - urlBase: A custom URL base for the SnapAuth API. This should usually
    ///   be omitted and left as the default value.
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
        continuation?.resume(returning: .failure(.newRequestStarting))
        continuation = nil
        logger.debug("Canceling pending requests")
        // Do this after the continuation is cleared out, so it doesn't run twice and break
        if authController != nil {
            #if !os(tvOS)
            if #available(iOS 16.0, macOS 13.0, visionOS 1.0, *) {
                logger.debug("Canceling existing auth controller")
                authController!.cancel()
            }
            #endif
            authController = nil
        }
    }

    /// Starts the passkey enrollment process by displaying a system dialog.
    ///
    /// The task will complete when the user approves or rejects the request, or
    /// if the request cannot be fulfilled.
    ///
    /// - Parameters:
    ///   - name: The name of the user. This should be a username or handle.
    ///   - displayName: The proper name of the user. If omitted, name will be used.
    ///   - authenticators: What authenticators should be permitted. If omitted,
    ///     all available types for the platform will be allowed.
    ///
    /// - Returns: A `Result` containing either `SnapAuthTokenInfo` upon success
    ///   or a `SnapAuthError` upon failure.
    ///
    /// # Example
    /// ```swift
    /// Task {
    ///     let result = await snapAuth.startRegister(name: "username@example.com")
    ///     switch result {
    ///     case .success(let registration):
    ///         // send registration.token to your backend to create the credential
    ///     case .failure(let error):
    ///         // Examine the error and decide how best to proceed
    ///     }
    /// }
    /// ```
    public func startRegister(
        name: String,
        displayName: String? = nil,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async -> SnapAuthResult {
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
    ) async -> SnapAuthResult {
        reset()
        self.anchor = anchor

        let body = SACreateRegisterOptionsRequest(user: nil)
        let response = await api.makeRequest(
            path: "/attestation/options",
            body: body,
            type: SACreateRegisterOptionsResponse.self)

        guard case let .success(options) = response else {
            return .failure(response.getError()!)
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

        return await withCheckedContinuation { continuation in
            assert(self.continuation == nil)
            self.continuation = continuation
            controller.performRequests()

        }
    }

    internal var authenticatingUser: AuthenticatingUser?

    /// Starts the authentication process by displaying a system dialog.
    ///
    /// The task will complete when the user approves or rejects the request, or
    /// if the request cannot be fulfilled.
    ///
    /// - Parameters:
    ///   - user: The authenticating user's `id` or `handle`
    ///   - authenticators: What authenticators should be permitted. If omitted,
    ///     all available types for the platform will be allowed.
    ///
    ///
    /// - Returns: A `Result` containing either `SnapAuthTokenInfo` upon success
    ///   or a `SnapAuthError` upon failure.
    ///
    /// # Example
    /// ```swift
    /// Task {
    ///     let result = await snapAuth.startAuth(.handle("username@example.com"))
    ///     switch result {
    ///     case .success(let auth):
    ///         // send auth.token to your backend to verify
    ///     case .failure(let error):
    ///         // Examine the error and decide how best to proceed
    ///     }
    /// }
    /// ```
    public func startAuth(
        _ user: AuthenticatingUser,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async -> SnapAuthResult {
        await startAuth(user, anchor: .default, authenticators: authenticators)
    }

    /// This may be exposed publicly if the default anchor proves insufficient
    internal func startAuth(
        _ user: AuthenticatingUser,
        anchor: ASPresentationAnchor,
        authenticators: Set<Authenticator> = Authenticator.all
    ) async -> SnapAuthResult {
        reset()
        self.anchor = anchor
        self.authenticatingUser = user

        let body = ["user": user]

        let response = await api.makeRequest(
            path: "/assertion/options",
            body: body,
            type: SACreateAuthOptionsResponse.self)


        guard case let .success(options) = response else {
            return .failure(response.getError()!)
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
        return await withCheckedContinuation { continuation in
            assert(self.continuation == nil)
            self.continuation = continuation
            logger.debug("perform requests")
            controller.performRequests()
        }

        // Sometimes the controller just WILL NOT CALL EITHER DELEGATE METHOD, so... yeah.
        // Maybe start a timer and auto-fail if neither delegate method runs in time?
    }
}

/// A representation of the user that is trying to authenticate.
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
