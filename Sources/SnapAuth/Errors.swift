import AuthenticationServices

/// SnapAuth error codes
///
/// Authentication and credential registration can fail or be rejected in
/// numerous ways, and applications should be prepared to handle these
/// scenarios.
public enum SnapAuthError: Error {
    /// The network request was disrupted. This is generally safe to retry.
    case networkInterruption

    /// Only a single request can run at a time. A new request is starting, so
    /// the current one is being canceled.
    case newRequestStarting

    /// This needs APIs that are not supported on the current platform. You can
    /// use `if #available()` conditionals, or similar, to avoid this.
    case unsupportedOnPlatform

    // MARK: Internal errors, which could represent SnapAuth bugs

    /// The SDK received a response from SnapAuth, but it arrived in an
    /// unexpected format.
    ///
    /// If you encounter this, please reach out to us.
    case malformedResposne

    /// The SDK was unable to encode data to send to SnapAuth.
    ///
    /// If you encounter this, please reach out to us.
    case sdkEncodingError

    /// The request was valid and understood, but processing was refused.
    ///
    /// If you encounter this, please reach out to us.
    case badRequest

    // MARK: Weird responses

    /// `ASAuthorizationServices` sent SnapAuth an unexpected type of response
    /// which we don't know how to handle.
    ///
    /// If you encounter this, please reach out to us.
    case unexpectedAuthorizationType

    /// Some of the data SnapAuth requested during credential registration was
    /// not provided, so we cannot proceed.
    case registrationDataMissing

    // MARK: Duplicated/relayed from ASAuthorizationError

    /// An unknown error occurred.
    case unknown

    /// Request canceled, which can either be explicit (such as the user
    /// canceling) or implicit (such as no matching credentials available)
    case canceled

    /// There was an invalid response from the authenticator.
    case invalidResponse

    // (Usage unknown, Apple docs are not clear - timeout?)
    case notHandled

    /// Authorization failed. This is often due to incorrect setup of Associated
    /// Domains, or an API key that does not match the Associated Domains.
    case failed

    // (Usage unknown, Apple docs are not clear)
    case notInteractive

    /// Registration matched an excluded credential. Typically this means that
    /// the credential has already been registered.
    case matchedExcludedCredential
}

/// Extension to standardize converstion of AS error codes into SnapAuth codes
extension ASAuthorizationError.Code {
    var snapAuthError: SnapAuthError {
        switch self {
        case .canceled: return .canceled
        case .failed: return .failed
        case .unknown: return .unknown
        case .invalidResponse: return .invalidResponse
        case .notHandled: return .notHandled
        case .notInteractive: return .notInteractive
        default:
            // This case only exists on new OS platforms
            if #available(iOS 18, visionOS 2, macOS 15, tvOS 18, *) {
                if case .matchedExcludedCredential = self {
                    return .matchedExcludedCredential
                }
            }
            return .unknown
        }
    }
}
