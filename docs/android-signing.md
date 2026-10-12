# Android signing

Two fingerprints. Which one you use depends on what you are doing, and getting
this wrong produces a Google sign-in failure that looks like a network problem.

## Debug builds

Generated automatically by Android Studio at `~/.android/debug.keystore`.

```
E3:47:D0:AF:C9:69:C2:B7:DF:AA:60:31:BD:2B:9B:17:D0:E8:F0:D7
```

Add this to your Android OAuth client. Google sign-in works on debug builds
with this fingerprint and nothing else.

## Release builds

The keystore is `app/android/islandads-release.jks` (gitignored).

```
4C:7F:74:2F:7D:C3:47:0C:40:C2:82:56:47:41:2D:74:76:4D:3B:F6
```

**Add this too.** A client that only has the debug fingerprint will fail
sign-in in the Play Store build, and the error message gives no hint that a
fingerprint is the cause. Both fingerprints go in the *same* OAuth client.

## Where to add it

Google Cloud Console → Credentials → your Android OAuth client → SHA-1
certificate fingerprints → +. Or re-upload the `google-services.json` that
FlutterFire generates.

## Credentials

```
storePassword=islandads2026
keyPassword=islandads2026
keyAlias=islandads
```

**These are in this file because they are a development placeholder. Change
them before release**, or move them to `key.properties` which is gitignored and
read by `android/key.properties`.

The keystore is the more serious problem: if it is lost and the password is
forgotten, the app cannot be updated on Play ever again. Back it up somewhere
durable — cloud storage, not this folder.

## Android package name

Currently `com.antiguamap.antigua_business_map`. This must match the OAuth
client's package name exactly, including case.

Changing it after publishing to Google Play is not possible. If it should become
`com.islandads.app`, that has to happen now.

## iOS

iOS does not use SHA-1 fingerprints. It needs an iOS OAuth client with the
bundle id, and a `.p8` service account key file that never enters the app
bundle.