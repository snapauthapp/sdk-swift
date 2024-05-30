## Setting up Associated Domains

Native apps require configuring Associated Domains in order to support passkeys.
This allows a domain to provide an allow-list of apps that may authenticate using a saved passkey or other authenticator.

> [!WARNING]
> If you have not configured Associated Domains, all SnapAuth APIs will immediately fail!


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

On iOS devices, this is done in Settings.app -> Developer -> Associated Domains Development
