# Android signing and identity

## Package name

`com.dadliplug.app` (Android application id and iOS bundle id), set on
2026-10-22 before anything was published. It cannot change once the app is on
Google Play.

Everything registered to a package name must match it exactly:

- **Firebase** (push): the Android app in project `antiguamap-511219-9cb87`,
  and `app/android/app/google-services.json` downloaded from it. The build
  fails with "No matching client found for package name" until this matches.
- **Google sign-in**: an Android OAuth client in Google Cloud Console with
  this package name and both SHA-1 fingerprints below. Its client id is
  `GOOGLE_SIGN_IN_CLIENT_ID` in `.env`. The Web client
  (`GOOGLE_SIGN_IN_WEB_CLIENT_ID`) does not change.
- **Google Maps key**: if the key is restricted to Android apps, add the new
  package name with both SHA-1 fingerprints.

## Fingerprints

Getting these wrong produces a Google sign-in failure that looks like a network
problem. Both go in the *same* Android OAuth client.

**Debug** (`~/.android/debug.keystore`, made by Android Studio):

```
SHA-1   E3:47:D0:AF:C9:69:C2:B7:DF:AA:60:31:BD:2B:9B:17:D0:E8:F0:D7
SHA-256 EC:85:43:6C:CF:ED:EF:6B:DF:99:41:2D:74:3F:74:A3:67:4D:9E:5E:93:FC:7D:10:7E:7F:50:92:D4:9F:7B:2A
```

**Upload key** (signs release builds you upload to Play):

```
SHA-1   76:10:FC:6F:CA:36:83:CB:C6:22:9C:B5:C0:0D:4A:0D:28:90:2A:39
SHA-256 46:D6:F8:C9:5F:66:D4:59:39:6D:93:A0:73:C4:C3:E6:33:32:A0:2B:B4:45:1D:B9:A5:88:3A:89:AD:83:6C:5A
```

**Play app signing key**: with Play App Signing (the default), Google re-signs
the app it installs with its own key. After the first upload, copy that key's
SHA-1 from Play Console → Setup → App signing, and add it to the same OAuth
client. Without it, sign-in fails only in the Play Store build.

## The upload key

- Keystore: `C:\Users\wilheim leeshu\.dadliplug-keys\dadliplug-upload.jks`,
  outside the repo. Alias `upload`. RSA 4096, valid 10,000 days.
- Passwords: `app/android/key.properties` (gitignored), read by
  `app/android/app/build.gradle.kts`. Without that file, release builds are
  debug-signed and the Play Console refuses them.
- **Back up both files** (the `.jks` and `key.properties`) somewhere durable
  and private, such as a password manager. With Play App Signing a lost upload
  key can be reset through Play support, but that takes days.

`app/android/islandads-release.jks` is a retired placeholder from Phase 1. Its
password was committed to this file in the past, so it must never sign
anything. It can be deleted.

## iOS

iOS does not use SHA-1 fingerprints. It needs an iOS OAuth client with the
bundle id `com.dadliplug.app`, and a `.p8` key that never enters the app
bundle. A `GoogleService-Info.plist` for push comes from registering the iOS
app in Firebase with the same bundle id.
