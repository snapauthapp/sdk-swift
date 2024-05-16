import Foundation

public protocol SnapAuthDelegate {
    func snapAuth(didAuthenticate authenticationResponse: SAAuthResponse) async
//    func snapAuth(didRegister registrationResponse: SAAuthResponse) async
    // didBeginProcessing(registration/authn/autofill)

    func sa(didAuth auth: Result<SnapAuthAuth, AuthenticationError>) async
}
/*
 extension SnapAuthDelegate {
//    func snapAuth(didAuthenticate authenticationResponse: SAAuthResponse) async {
//        // No-op by default
//    }
}
*/

/// TODO: rename this!
public struct SnapAuthAuth {
  public let token: String
  public let expiresAt: Date
}
