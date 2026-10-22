# iOS: from this repo to TestFlight

iOS apps can only be built on a Mac with Xcode. This project is developed on
Windows, so the build runs on a cloud Mac: GitHub Actions (`macos-latest`, the
`build-ios` job in `.github/workflows/flutter.yml`) or Codemagic. Everything
below except the build itself can be done from Windows in a browser.

Bundle id: **`com.dadliplug.app`** (set 2026-10-22, same as Android).

## 1. Apple (needs the Apple Developer Program, US$99 a year)

1. Enrol at developer.apple.com. Decide whose account it is (plan.md 15,
   "who holds the Apple and Google credentials"): an organisation account
   shows the company as the seller and needs a D-U-N-S number.
2. Certificates, Identifiers & Profiles → Identifiers → **+** → App ID
   `com.dadliplug.app`, capabilities: **Push Notifications**,
   **Sign in with Apple** (see step 5).
3. App Store Connect → My Apps → **+** → new app, bundle id as above, name
   "Dadliplug".
4. Keys → **+** → an **App Store Connect API key** (for the cloud Mac to
   upload builds) and an **APNs key** (.p8, for push). Download each once;
   Apple will not show them again. Store them with the Android upload key,
   never in the repo.

## 2. Google sign-in on iOS

1. Google Cloud Console, project **antiguamap-511219** (the one with the Web
   client, not the Firebase project) → Credentials → Create OAuth client →
   **iOS**, bundle id `com.dadliplug.app`.
2. Put its client id in `.env` as `GOOGLE_SIGN_IN_IOS_CLIENT_ID=`.
3. Add its **reversed** client id as a URL scheme in `app/ios/Runner/Info.plist`
   (Google's callback returns to the app through it). For a client id
   `154710325721-abc.apps.googleusercontent.com` the scheme is
   `com.googleusercontent.apps.154710325721-abc`:

   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.154710325721-abc</string>
       </array>
     </dict>
   </array>
   ```

## 3. Maps

Nothing to add to Xcode: the app passes the key from `.env` to iOS at start-up
(`main.dart` → `AppDelegate.swift`). If the Maps key is restricted by app, add
an **iOS** restriction for `com.dadliplug.app`.

## 4. Push notifications on iOS (later)

Push is Android-only today (`PushService.init` returns early elsewhere). To
add iOS:

1. Firebase console, project `antiguamap-511219-9cb87` → add an **iOS** app,
   bundle id `com.dadliplug.app` → download `GoogleService-Info.plist` into
   `app/ios/Runner/` (gitignored like `google-services.json`).
2. Firebase → Project settings → Cloud Messaging → upload the **APNs key**.
3. Add the Push Notifications capability and the `remote-notification`
   background mode, then let `PushService.init` run on iOS.

## 5. Sign in with Apple (App Store guideline 4.8)

An iOS app that offers Google sign-in must also offer an equivalent login that
limits data to name and email and allows hiding the email. Sign in with Apple
is the usual answer. Email and password sign-up may not count. Decide before
the first App Review; adding it is a Supabase provider plus the
`sign_in_with_apple` package.

## 6. Build and upload

**GitHub Actions:** the repo has no remote yet. Push it to a **private**
GitHub repository; the `build-ios` job then compiles an unsigned build on
every push to `main`, which proves the iOS project builds. A signed build for
TestFlight adds the App Store Connect API key as repository secrets and a
`flutter build ipa` step.

**Codemagic** (simpler for signing): connect the repo, give it the App Store
Connect API key, and it creates certificates and profiles and uploads to
TestFlight. Free tier: 500 macOS build minutes a month.

Dart-defines (Supabase, Google, Maps keys) must be passed to the iOS build
exactly as `scripts/build-apk.ps1` does for Android: from `.env`, never
committed. In CI they are repository secrets.

## 7. Before App Review

- Privacy "nutrition label" in App Store Connect: email, name, user content
  (reviews), identifiers (push token); none used for tracking. Match
  `app/assets/legal/privacy.md`.
- Privacy policy URL and account deletion: `/privacy` and in-app delete
  (guideline 5.1.1(v)) are built; the Worker must be deployed.
- User-generated content (guideline 1.2): report, hide-a-reviewer and a
  contact address are built; set `SUPPORT_EMAIL`.
- Payments (guidelines 3.1.1, 3.1.3): businesses pay by bank transfer outside
  the app and the app sells nothing to consumers. Say so in the review notes.
