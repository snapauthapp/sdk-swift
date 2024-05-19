// FIXME: Go through and ensure errors are complete and accurate.
public enum AuthenticationError: Error {
    /// The user canceled
    case canceled
    /// There was a network interruption
    case networkDisrupted

    case asAuthorizationError
}
