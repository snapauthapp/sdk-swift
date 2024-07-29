# ``SnapAuth``

The official SnapAuth SDK for Apple platforms.

## Overview

SnapAuth allows you to quickly, easily, and reliably add passkeys to your web and native apps.
You can be up and running in minutes on all platforms without ever having to look at `AuthenticationServices`.

This SDK supports all native Apple platforms that permit passkey use (everything but Apple Watch).

## Topics

### Setup

To start, import the SnapAuth SDK and provide it your _publishable key_ from the [SnapAuth dashboard](https://dashboard.snapauth.app).

```swift
import SnapAuth

let snapAuth = SnapAuth(publishableKey: "pubkey_your_key")
```

- ``SnapAuth/SnapAuth``
- ``SnapAuth/SnapAuth/init(publishableKey:urlBase:)``

### Credential Registration

Create a new passkey (or associate a hardware key) for the user.

- ``SnapAuth/startRegister(name:displayName:authenticators:)``

### Authentication

Authenticate a user using their previously-registered passkey or hardware key.

- ``SnapAuth/SnapAuth/startAuth(_:authenticators:)``
- ``SnapAuth/AuthenticatingUser``

### Credential AutoFill

When a user focuses a `TextField` with `.textContentType(.username)`, the QuickType bar can suggest passkeys.
This allows the user to authenticate without even having to fill in their username.

AutoFill is only available on iOS and visionOS. 

- ``SnapAuth/SnapAuth/handleAutoFill()``

### Controlling Authenticator Types

For the best user experience and most flexibility, allow all of the platform's supported authenticators.
Passkeys are supported on all platforms.
External hardware authenticators are not supported on tvOS or visionOS.

- ``SnapAuth/SnapAuth/Authenticator``

### Handling Responses

All of the SDK's core methods will return a `SnapAuthResult`, which is an alias for `Result<SnapAuthTokenInfo, SnapAuthError>`.
Inspect the result to decide how to proceed.

```swift
let result = await snapAuth.startAuth(.id("usr_123456"))
switch result {
case .success(let auth):
  // Send auth.token to your backend to sign in the user
case .failure(let error):
  // Examine the error and decide how best to proceed
}
```

- ``SnapAuth/SnapAuthResult``
- ``SnapAuth/SnapAuthTokenInfo``
- ``SnapAuth/SnapAuthError``
