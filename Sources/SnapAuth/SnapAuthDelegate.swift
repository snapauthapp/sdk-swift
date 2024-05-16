import Foundation

public protocol SnapAuthDelegate {
//    func snapAuth(didAuthenticate authenticationResponse: SAAuthResponse) async
//    func snapAuth(didRegister registrationResponse: SAAuthResponse) async
    // didBeginProcessing(registration/authn/autofill)

    func snapAuth(didFinishAuthentication result: Result<SnapAuthAuth, AuthenticationError>) async
}
/*
 extension SnapAuthDelegate {
//    func snapAuth(didAuthenticate authenticationResponse: SAAuthResponse) async {
//        // No-op by default
//    }
}
*/

/// TODO: rename this!
/// Also, can this be a typealias of the wire format internal?
public struct SnapAuthAuth {
  public let token: String
  public let expiresAt: Date
}
