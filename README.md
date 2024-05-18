# SnapAuth Swift SDK

This is the official Swift SDK for [SnapAuth](https://www.snapauth.app).

## Platform Support

This SDK supports all major Apple platforms that support passkeys:

Platform | Passkeys | Hardware Keys
--- | --- |---
iOS | Yes | Yes
iPadOS | Yes | Yes
macOS | Yes | Yes
visionOS | Yes | No[^no-platform]
tvOS | ⚠️[^platform-unested] | No[^no-platform]
watchOS | No[^no-platform] | No[^no-platform]

## Setup

If you haven't already registered for SnapAuth, do so: https://www.snapauth.app/register

Use it to get your `publishable key` from the Dashboard.

### Add the SDK

XCode > File > Add Package Dependencies...

In the add package dialog, search for our SDK:

`https://github.com/snapauthapp/sdk-swift`

Select a Dependency Rule and add it to your development target.
We recommend "Dependency Rule: Up to Next Major Version".

### Import the SDK

In any files that need to integrate with SnapAuth, be sure to import it:

```swift
import SnapAuth
```

## Usage

SnapAuth will get you up and running with passkeys in a snap!

### Implement `SnapAuthDelegate`

If using SwiftUI, this can be done directly on a `View`.
You may also do this in a separate class or struct.

This will be called by our SDK when a user either authenticates or cancels the request.

Example:
```swift
import SnapAuth

func snapAuth(didFinishAuthentication result: Result<SnapAuthAuth, AuthenticationError>) async {
    guard case .success(let auth) = result else {
        // User did not or could not authenticate. Update your UI accordingly
        return
    }
    // Send `auth.token` to your backend for server-side verification. Use it to
    // determine the authenticating user, and send back an appropriate response
    // to the client code.
}
```

Registration is substantially the same.

### Call the API

This will typically be done in a Button's action.
Here's a very simple sign-in View in SwiftUI:

```swift
import SnapAuth
import SwiftUI

struct SignInView: View {
  let snapAuth = SnapAuth(publishableKey: "pubkey_yourkey")

  @State var username: String = ""

  var body: some View {
    VStack {
      TextField("Username", text: $username)
      Button("Sign In", systemImage: "person.badge.key") {
        signIn()
      }
    }
  }

  func signIn() {
    Task {
      snapAuth.delegate = self
      await snapAuth.startAuth(.handle(username), anchor: ASPresentationAnchor())
    }
  }
}
extension SignInView: SnapAuthDelegate {
  // delegate methods described above
}
```

[^no-platform]: Unsupported by Apple (no USB port!)
[^platform-untested]: Untested, but will probably work
