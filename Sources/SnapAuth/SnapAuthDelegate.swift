import Foundation

/// An interface for providing information about the outcome of a SnapAuth request
public protocol SnapAuthDelegate {
    /// Tells the delegate when SnapAuth finished a modal authentication request.
    ///
    /// Implementations should examine the result to determine if it was a
    /// success or failure, and proceed accordingly.
    ///
    /// ```
    /// func snapAuth(didFinishAuthentication result: SnapAuthResult) async {
    ///     switch result {
    ///     case .success(let auth):
    ///         // Send auth.token to your backend
    ///     case .failure(let error):
    ///         // Examine error to decide how to proceed
    ///     }
    /// }
    /// ```
    func snapAuth(didFinishAuthentication result: SnapAuthResult) async

    /// Tells the delegate when SnapAuth finished a registration request.
    ///
    /// Implementations should examine the result to determine if it was a
    /// success or failure, and proceed accordingly.
    ///
    /// ```
    /// func snapAuth(didFinishRegistration result: SnapAuthResult) async {
    ///     switch result {
    ///     case .success(let registration):
    ///         // Send registration.token to your backend
    ///     case .failure(let error):
    ///         // Examine error to decide how to proceed
    ///     }
    /// }
    /// ```
    func snapAuth(didFinishRegistration result: SnapAuthResult) async
}

public struct SnapAuthTokenInfo {
    /// The registration or authentication token.
    ///
    /// This cannot be used directly by your client app.
    /// It must be sent to your backend for verification, which will use a
    /// server SDK to either create a credential or verify the authentication.
    public let token: String

    /// When the paired token will expire.
    ///
    /// If you try to use it after this time (or more than once), the request
    /// will be rejected.
    public let expiresAt: Date
}

public typealias SnapAuthResult = Result<SnapAuthTokenInfo, SnapAuthError>
