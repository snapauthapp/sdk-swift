/* FIXME: Go through and ensure errors are complete and accurate.
public enum AuthenticationError: Error {
    /// The user canceled
    case canceled
    /// There was a network interruption
    case networkDisrupted

    case asAuthorizationError
}
 */


public enum SnapAuthError: Error {
    /// The network request was disrupted.
    case networkInterruption

    /// The SDK received a response from SnapAuth, but it arrived in an unexpected format. If you encounter this, please reach out to us.
    case malformedResposne

    /// The SDK was unable to encode data to send to SnapAuth. If you ever encounter this, please reach out to us.
    case sdkEncodingError

    /// The request was valid and understood, but processing was refused.
    case badRequest


    /// ASAuthorizationServices sent SnapAuth an unexpected type of response which we don't know how to handle. If you encounter this, please reach out to us.
    case unexpectedAuthorizationType

    /// Some of the data SnapAuth requested during credential registration was not provided, so we cannot proceed.
    case registrationDataMissing

    // Duplicated (ish) from ASAuthorizationError
    case unknown
//    case canceled
//    case invalidResponse
//    case notHandled
//    case failed
//    case notInteractive
}
