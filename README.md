# SnapAuth Swift SDK

This is the official Swift SDK for [SnapAuth](https://www.snapauth.app?utm_source=GitHub&utm_campaign=sdk&utm_content=sdk-swift).

🚧 This SDK is in beta! 🚧

![GitHub License](https://img.shields.io/github/license/snapauthapp/sdk-typescript)

- [SnapAuth Homepage](https://www.snapauth.app?utm_source=GitHub&utm_campaign=sdk&utm_content=sdk-swift)
- [Docs](https://docs.snapauth.app)
- [Dashboard](https://dashboard.snapauth.app)
- [Github](https://github.com/snapauthapp/sdk-swift)

## Platform Support

This SDK supports all major Apple platforms that support passkeys and hardware authenticators:

Platform | Passkeys | Hardware Keys
--- | --- | ---
iOS | ✅ 15.0+ | ✅[^usb-hardware-varies] 15.0+
iPadOS | ✅ 15.0+ | ✅[^usb-hardware-varies] 15.0+
macOS | ✅ 12.0+ | ✅ 12.0+
visionOS | ✅ 1.0+ | ❌[^no-usb]
tvOS | ⚠️[^platform-untested] 16.0+ | ❌[^no-usb]
watchOS | ❌[^no-watch] | ❌[^no-watch]

## Apple-specific setup

> [!IMPORTANT]
> All native apps require special domain confirmation to use.
> This cannot be skipped!

If you haven't already registered for SnapAuth, do so: https://www.snapauth.app/register

Unlike for web integrations, `localhost` generally does not work nicely on Apple native apps.
It should be possbile, but unlike on web must still use `https` which local environments don't always support well.
Starting with a testing or staging server is often an easier place to start.

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

> [!WARNING]
> This capability is restricted on free Apple Developer accounts.
> Unfortunately, this means you must have a current, paid account to proceed.

<!-- Also, personal accounts might not work? -->

In the new Associated Domains section, click `+` and add your domain(s):

`webcredentials:yourdomain.tld`

This should match the `RP ID` from the SnapAuth dashboard.

<!-- Must match exactly? Registrable domain match? -->

### Publish the domain association file

Create the assoication file (or, if you already have one for other capabilities, add this section):

```json
{
  "webcredentials": {
    "apps": [
      "your App ID"
    ]
  }
}
```

This file must be served at `https://yourdomain.tld/.well-known/apple-app-site-association`.

`curl https://yourdomain.tld/.well-known/apple-app-site-association` to test it.

> [!CAUTION]
> If you already have a Domain Association file, be sure only to append or merge this change.
> Do not replace other content in the file, which could lead to breaking other app functionality!

#### Your App ID

Your App ID can be obtained from the Apple developer portal(s):

https://developer.apple.com/account/resources/identifiers/list > Select your app

or

https://developer.apple.com/account#MembershipDetailsCard > Look for Team ID, and

XCode > Your app (the root-level object in Navigator) > Targets > (pick one) > General, look for Bundle Identifier

The App ID is the combination of the Team ID (typically 10 characters) and the Bundle ID (typically configured in-app, frequently in reverse-DNS format): `TeamID.BundleID`

This will result in something like `A5B4C3D2E1.tld.yourdomain.YourAppName`

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

## Usage

SnapAuth will get you up and running with passkeys in a snap!

### Add the SDK

XCode > File > Add Package Dependencies...

In the add package dialog, search for our SDK:

`https://github.com/snapauthapp/sdk-swift`

Select a Dependency Rule and add it to your development target.
We recommend "Dependency Rule: Up to Next Major Version".

We follow Semantic Versioning with all of our SDKs, so this should always be a safe option.

### Import the SDK

In any files that need to integrate with SnapAuth, be sure to import it:

```swift
import SnapAuth
```

### Implement `SnapAuthDelegate`

If using SwiftUI, this can be done directly on a `View`.
You may also do this in a separate class or struct.

This will be called by our SDK when a user either authenticates or cancels the request.

Example:
```swift
import SnapAuth

func snapAuth(didFinishAuthentication result: SnapAuthTokenInfo) async {
    guard case .success(let auth) = result else {
        // User did not or could not authenticate.
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

## Known issues

In our testing, the sign in dialog in tvOS doesn't open, at least in the simulator.

Even with the Apple-documented configuration, the AutoFill API does not reliably provide passkey suggestions.

## Useful resources

 - [WWDC21: Move beyond passwords](https://developer.apple.com/videos/play/wwdc2021/10106/)
 - [WWDC22: Meet passkeys](https://developer.apple.com/videos/play/wwdc2022/10092/)
 - [Supporting associated domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains)
 - [Associated domains entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_associated-domains)
 - https://forums.developer.apple.com/forums/thread/743890

## License

BSD-3-Clause

[^no-watch]: Passkeys are not supported on Apple Watch
[^no-usb]: Unsupported by Apple (no USB port!)
[^platform-untested]: Untested, but will probably work
[^usb-hardware-varies]: Supported at the platform level, but compatibility varies by device. As a general rule, if it physically fits, it should work.
