# Setting up Associated Domains

Native apps **require** configuring Associated Domains in order to support passkeys.
This allows a domain to provide an allow-list of apps that may authenticate using a saved passkey or other authenticator.

> [!IMPORTANT]
> If you have not configured Associated Domains, all SnapAuth APIs will immediately fail!
> This involves publishing a JSON file on your domain, and updating a setting in Xcode.

## Xcode

### Add the Associated Domains capability

You may have already done this if your existing app supports password autofill.
Still, fully review this section!

In XCode, select your root-level project in the Navigator.

Select your Target, and navigate to the Signing & Capabilities tab.

Click `+ Capability` and select `Associated Domains`

> [!NOTE]
> This capability is unavailable on free Apple Developer accounts.
> Unfortunately, this means you **must have a current, paid account** to proceed.

In the new Associated Domains section, click `+` and add your domain(s):

`webcredentials:yourdomain.tld`

This should match the `RP ID` from the SnapAuth dashboard.

<!-- Must match exactly? Registrable domain match? -->

## Website

### Create (or update) the domain association file

Create the assoication file (or, if you already have one for other capabilities, add this section):

```json
{
  "webcredentials": {
    "apps": [
      "<Team ID>.<Bundle ID>"
    ]
  }
}
```

This full string in `apps` will look something like `A5B4C3D2E1.tld.yourdomain.YourAppName`. 
See below for details.

> [!CAUTION]
> If you already have a Domain Association file, be sure only to append or merge this change.
> Do not replace other content in the file, which could lead to breaking other app functionality!

### `Team ID`

> [!WARNING]
> The `TeamId` is NOT the App ID from App Store Connect, nor is it your personal developer ID.
> Even if you're registered as an individual developer account, you still have a Team ID.
>
> If you publish the incorrect id in this file, you may have to wait a while before being able to proceed.
> It's cached fairly aggressively by Apple's CDNs, and there's no known way to force a cache bust.
> See the bottom of this page for a possible workaround.

This can be found in a few different places with the Apple developer portal.
Depending on your role and permissions, not all may work.

1) https://developer.apple.com/account/resources/identifiers/list
  - Select your app
  - Look near the top for `App ID Prefix`

2) https://developer.apple.com/account#MembershipDetailsCard
  - Scroll down to Membership Details
  - Look for Team ID

3) https://appstoreconnect.apple.com/access/users
  - Click into your own account
  - Look for Team ID 

### `Bundle Id`
XCode > Your app (the root-level object in Navigator) > Targets > (pick one) > General, look for Bundle Identifier



### Publish the file

This file must be served at `https://yourdomain.tld/.well-known/apple-app-site-association`.

`curl https://yourdomain.tld/.well-known/apple-app-site-association` to test it.

It should be served with an `application/json` `mime-type`, but it's not strictly required.
Be sure it's not blocked by robots.txt or firewall rules.


## Optional: enable SWC Developer Mode

In production applications, Apple caches the Associated Domains file for about a day.
For local development of a macOS app, you can bypass this cache:

1) _Add_ a second entry to the Associated Domains section:
`webcredentials:yourdomain.tld?mode=developer`

2) Enable this feature on your development computer:

```bash
sudo swcutil developer-mode -e 1
```

(To disable in the future, run the above command again with `1` replaced with `0`)

You still **must** publish the association file; this only bypasses the cache.

On iOS devices, this is done in Settings.app -> Developer -> Associated Domains Development

## External Resources

More info:

- https://developer.apple.com/documentation/xcode/supporting-associated-domains
- https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_developer_associated-domains
