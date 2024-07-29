import Foundation

/// The success case of adding or using a passkey.
///
/// `SnapAuthTokenInfo` is the result of a successful authentication or credential registration.
///
/// This holds a short-lived token which should be sent to your application's backend for verifcation and use.
///
/// The token on its own does not authenticate a user; instead, the token must be sent to your application's backend for processing and verification.
/// Tokens are short-lived and one-time-use.
///
/// See our [server documentation](https://docs.snapauth.app/server.html) for additional info on how to use these tokens.
public struct SnapAuthTokenInfo {
    /// The registration or authentication token.
    ///
    /// This cannot be used directly by your client app.
    /// It must be sent to your backend for verification, which will use a
    /// server SDK to either create a credential or verify the authentication.
    public let token: String

    /// When the paired token will expire.
    ///
    /// If you try to use it after this time, or more than once, the request
    /// will be rejected.
    public let expiresAt: Date
}

/// An alias for the native `Result` type with our success and failure states.
public typealias SnapAuthResult = Result<SnapAuthTokenInfo, SnapAuthError>
