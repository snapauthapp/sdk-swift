public enum SnapAuthError: Error {
    /// The network request was disrupted. This is generally safe to retry.
    case networkInterruption

    // MARK: Internal errors, which could represent SnapAuth bugs

    /// The SDK received a response from SnapAuth, but it arrived in an
    /// unexpected format. If you encounter this, please reach out to us.
    case malformedResposne

    /// The SDK was unable to encode data to send to SnapAuth. If you encounter
    /// this, please reach out to us.
    case sdkEncodingError

    /// The request was valid and understood, but processing was refused. If you
    /// encounter this, please reach out to us.
    case badRequest

    // MARK: Weird responses

    /// ASAuthorizationServices sent SnapAuth an unexpected type of response
    /// which we don't know how to handle. If you encounter this, please reach
    /// out to us.
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
}
