# SnapAuth Swift SDK

This is the official Swift SDK for [SnapAuth](https://www.snapauth.app).

## Platform Support

This SDK supports all major Apple platforms that support passkeys:

Platform | Passkeys | Hardware Keys
--- | --- |---
iOS | ✅ | ✅
iPadOS | ✅ | ✅
macOS | ✅ | ✅
visionOS | ✅ | ❌[^no-platform]
tvOS | ⚠️[^platform-untested] | ❌[^no-platform]
watchOS | ❌[^no-platform] | ❌[^no-platform]

## Setup

> [!IMPORTANT]
> All native apps require special domain confirmation to use.
> This cannot be skipped!

If you haven't already registered for SnapAuth, do so: https://www.snapauth.app/register

Unlike for web integrations, `localhost` generally does not work on Apple native apps.

You should immediately create a non-local environment to test with, if you haven't already done so.
Starting with a testing or staging server is a good place to start.

<!--
The `RP ID` from the dashbard _must_ exactly match the Associated Domains configuration below

(This needs to be verified - the AD is what'll get checked for the file, but a subdomain match on the RP ID might be ok)
-->

### Add the Associated Domains capability

> [!TIP]
> You may have already done this if your existing app supports password autofill.
> 
> Still, fully review this section!

More info:

- https://developer.apple.com/documentation/xcode/supporting-associated-domains
- https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_associated-domains

In XCode, select your root-level project in the Navigator.

Select your Target, and navigate to the Signing & Capabilities tab.

Click `+ Capability` and select `Associated Domains`

> [!NOTE]
> This capability is restricted on free Apple Developer accounts.
> Unfortunately, this means you must have a current, paid account to proceed.

In the new Associated Domains section, click `+` and add your domain(s):

`webcredentials:yourdomain.tld`


### Publish the domain association file

Get your App ID from the Apple Developer portal.

Create the assoication file (or, if you already have one for other capabilities, add this section):

```json
{
  "webcredentials": {
    "apps": [
      "your app id"
    ]
  }
}
```

This file must be served at `https://yourdomain.tld/.well-known/apple-app-site-association`.

`curl https://yourdomain.tld/.well-known/apple-app-site-association` to test it.

#### Optional: enable SWC Developer Mode

In production applications, Apple caches the Associated Domains file for about a day.
For local development, you can bypass this cache:

1) _Add_ a second entry to the Associated Domains section:
`webcredentials:yourdomain.tld?mode=developer`

2) Enable this feature on your development computer:

```bash
sudo swcutil developer-mode -e 1
```

(To disable in the future, run the above command again with `1` replaced with `0`)

You still **must** publish the association file; this only bypasses the cache.



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

Grab your `publishable key` from the SnapAuth Dashboard; you'll use it below.

This will typically be done in a Button's action.
Here's a very simple sign-in View in SwiftUI:

```swift
import SnapAuth
import SwiftUI

struct SignInView: View {
  let snapAuth = SnapAuth(publishableKey: "pubkey_yourkey") // Set this value!

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
