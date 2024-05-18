import Foundation

public protocol SnapAuthDelegate {
    func snapAuth(didFinishAuthentication result: Result<SnapAuthAuth, AuthenticationError>) async

    func snapAuth(didFinishRegistration result: Result<SnapAuthAuth, AuthenticationError>) async
}


/// TODO: rename this!
/// Also, can this be a typealias of the wire format internal?
public struct SnapAuthAuth {
  public let token: String
  public let expiresAt: Date
}
