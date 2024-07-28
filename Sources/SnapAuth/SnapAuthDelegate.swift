import Foundation

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
