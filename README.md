# SnapAuth Swift SDK

This is the official Swift SDK for [SnapAuth](https://www.snapauth.app?utm_source=GitHub&utm_campaign=sdk&utm_content=sdk-swift).

SnapAuth will let you add passkey support to your native app in a snap!

![GitHub Release](https://img.shields.io/github/v/release/snapauthapp/sdk-swift)
[![Swift Versions](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsnapauthapp%2Fsdk-swift%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/snapauthapp/sdk-swift)
[![Supported Platforms](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsnapauthapp%2Fsdk-swift%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/snapauthapp/sdk-swift)

[![Test](https://github.com/snapauthapp/sdk-swift/actions/workflows/test.yml/badge.svg)](https://github.com/snapauthapp/sdk-swift/actions/workflows/test.yml)
[![GitHub License](https://img.shields.io/github/license/snapauthapp/sdk-typescript)](https://github.com/snapauthapp/sdk-swift/blob/main/LICENSE)

- [SnapAuth Homepage](https://www.snapauth.app?utm_source=GitHub&utm_campaign=sdk&utm_content=sdk-swift)
- [Docs](https://docs.snapauth.app)
- [Dashboard](https://dashboard.snapauth.app)
- [Github](https://github.com/snapauthapp/sdk-swift)

## Platform Support

This SDK supports all major Apple platforms that support passkeys and hardware authenticators:

Platform | Passkeys | Hardware Keys | Notes
--- | --- | --- | ---
iOS | ✅ 15.0+ | ✅ 15.0+ |
iPadOS | ✅ 15.0+ | ✅ 15.0+ |
macOS | ✅ 12.0+ | ✅ 12.0+ |
macOS (Catalyst) | ⚠️ | ⚠️ | Still being tested (should work)
visionOS | ✅ 1.0+ | ❌ | Hardware keys are not supported on visionOS
tvOS | ⚠️ 16.0+ | ❌ | Still being tested, hardware keys are not supported on tvOS

Apple Watch does not support passkeys or hardware keys, so watchOS is not supported by this SDK.
If support is added in a future watchOS release, we will do the same!

## Getting Started

### Register for SnapAuth

If you haven't already registered for SnapAuth, you'll need to do so: https://www.snapauth.app/register

Unlike for web integrations, `https` is still required even for `localhost` (web intergrations permit `http://localhost`).
Depending on your development setup, you may want to immediately add a testing or staging server environment.

> [!TIP]
> If you need help with this, we're happy to help - just send us an email!

### Set up associated domains

> [!WARNING]
> This is not SnapAuth-specific, but must be completed or the APIs will immediately return errors.

See the [Associated Domains setup guide](/DOMAINS.md) to configure your app to support passkeys.

### Add the SnapAuth SDK

XCode > File > Add Package Dependencies...

In the add package dialog, search for our SDK:

```
https://github.com/snapauthapp/sdk-swift
```

Select a Dependency Rule and add it to your development target.
We recommend "Dependency Rule: Up to Next Major Version".

We follow Semantic Versioning with all of our SDKs, so this should always be a safe option.

### Import the SDK

In any files that need to integrate with SnapAuth, be sure to import it:

```swift
import SnapAuth
```

### Call the API

Grab your `publishable key` from the SnapAuth Dashboard; you'll use it below.

This will typically be done in a Button's action.
Here's a very simple sign-in View in SwiftUI:

```swift
import SnapAuth
import SwiftUI

struct SignInView: View {
  let snapAuth = SnapAuth(publishableKey: "pubkey_yourkey") // Set this value!

  @State var userName: String = ""

  var body: some View {
    VStack {
      TextField("Username", text: $userName)
      Button("Sign In", systemImage: "person.badge.key") {
        signIn()
      }
    }
  }

  func signIn() {
    Task {
      let result = await snapAuth.startAuth(.handle(userName))
      switch result {
      case .success(let auth):
        // Send auth.token to your backend to sign in the user
      case .failure(let error):
        // Decide how to proceed
      }
    }
  }
}
```

### Autofill-assisted Requests

> [!NOTE]
> Autofill is (at present) only supported on iOS/iPadOS >= 16 and visionOS.
> On other platforms or OS versions, this will immediately return a failure code
> indicating a lack of platform support.

To have the system suggest a passkey when a username field is focused, make the following additions to start the process and handle the result:

1. Add `.textContentType(.username)` to the username `TextField`, if not already set:

```swift
TextField("Username", text: $userName)
  .textContentType(.username) // <-- Add this
```

2. Run the autofill API when the view is presented:

```swift
// ...
var body: some View {
  VStack {
    // ...
  }
  .onAppear(perform: autofill) // <-- Add this
}

// And this
func autofill() {
  Task {
    let autofillResult = await snapAuth.handleAutofill()
    guard case .success(let auth) = autofillResult else {
      // Autofill failed, this is common and generally safe to ignore
      return
    }
    // Send auth.token to your backend to sign in the user, as above
  }
}
```

## Known issues

In our testing, the sign in dialog in tvOS doesn't open, at least in the simulator.

Even with the Apple-documented configuration, the AutoFill API does not reliably provide passkey suggestions.
There appears to be a display issue inside the SwiftUI and UIKit internals causing the suggestion bar to not render consistently.
We have filed a Feedback with Apple, but this is outside of our control.

## Useful resources

 - [WWDC21: Move beyond passwords](https://developer.apple.com/videos/play/wwdc2021/10106/)
 - [WWDC22: Meet passkeys](https://developer.apple.com/videos/play/wwdc2022/10092/)
 - [Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
 - [Associated domains entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_associated-domains)
 - https://forums.developer.apple.com/forums/thread/743890

## License

BSD-3-Clause
