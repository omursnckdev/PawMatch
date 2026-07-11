# PawMatch

Tinder-style iOS app for pet owners (playdates + breeding matches). Full product
spec, architecture, data model, and build plan live in [`CLAUDE.md`](./CLAUDE.md).

## Status

**Milestones 1–2 scaffolded** (Foundation & Auth; Pet Profiles). This was built
in a Linux container with no Xcode/Swift toolchain available, so the code has
been written carefully against the Firebase/SwiftUI APIs but has **not been
compiled or run** — the first thing to do on a Mac is open it in Xcode and fix
whatever the compiler finds. Treat this as a strong first draft, not a verified
build.

### Milestone 1 — Foundation & Auth
- Project structure generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  (no hand-authored `.xcodeproj` — see "Getting started" below).
- Firebase Auth (Sign in with Apple + email/password), App Check (App Attest /
  Debug provider), Crashlytics, and Analytics wired up per §5/§10.9.
- `users/{uid}` document creation on first sign-in.
- 18+ age confirmation gate (§10.6).
- Firestore security rules (`firestore.rules`) and Storage rules
  (`storage.rules`) covering the full data model in §6, including the
  server-write-only `isPremium`/`billingIssue` fields and bidirectional block
  enforcement — written ahead of the milestones that use them since the rules
  are cheap to get right early and expensive to retrofit.
- `CloudFunctions/` TypeScript project skeleton (builds, no functions
  implemented yet — those land in Milestones 4–5).

### Milestone 2 — Pet Profiles
- Multi-step profile creation (basics → photos → purpose → location) in
  `PetProfileSetupView`, driven by `PetProfileViewModel`.
- Photo picking via `PHPickerViewController` (no library permission needed,
  §10.4), client-side downscale + JPEG compression (`ImageProcessor`, §10.3),
  upload to Storage at `petPhotos/{ownerId}/{petId}/...`.
- Location permission with an in-app priming step before the OS prompt (§9),
  geohash computed on save via `GeoFireUtils` (§6.1).
- Reusable `PetCardView` (deck/match/detail, §9) and `PermissionPrimingView`.
- Edit / delete own pet; deleting also cleans up its Storage photos.
- Routing: a signed-in, age-confirmed user with 0 pets is sent to profile
  setup; with ≥1 pet they land on "My Pets" (temporary main surface until the
  tab bar arrives in Milestone 3).
- Unit tests for `AuthViewModel`, `PetProfileViewModel`, and `HomeViewModel`
  against protocol-mocked services (no live Firebase calls).

Not started: swipe deck, matching, chat, monetization, ads, report/block,
delete account, App Store assets, Fastlane. Follow `CLAUDE.md` §12 for order.

> Note: the "add a second pet is Plus-gated" path currently shows a placeholder
> note instead of a paywall — the real paywall is built in Milestone 5.

## Getting started (on a Mac)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Create a Firebase project, add an iOS app with bundle ID `com.pawmatch.app`,
   download `GoogleService-Info.plist` into `PawMatch/` (gitignored — never commit it).
4. Copy `Secrets.xcconfig.example` → `Secrets.xcconfig` and fill in real
   RevenueCat/AdMob keys (gitignored).
5. Copy `.firebaserc.example` → `.firebaserc` and set your real project ID.
6. In Xcode: enable the **Sign in with Apple** capability on the `PawMatch`
   target (requires an Apple Developer account) and the **Push Notifications**
   capability (needed starting Milestone 4).
7. Open `PawMatch.xcodeproj`, select the `PawMatch` scheme, and build.
8. For Firestore/Storage rules: `firebase deploy --only firestore:rules,storage:rules`
   (or `firebase emulators:start` to test locally first, per §11 — do this
   before every deploy, not just once).

## Repo layout

See `CLAUDE.md` §5 for the intended structure. `CloudFunctions/` is a separate
Node/TypeScript project deployed independently of the iOS app.

## Known gaps / TODOs before Milestone 6 (Publish Readiness)

- `PrivacyInfo.xcprivacy` only lists data collected by app code so far; expand
  it as RevenueCat/AdMob/additional Firebase products are integrated.
- `AppIcon.appiconset` has no actual 1024×1024 image yet.
- No Crashlytics dSYM-upload build phase yet — add one per Firebase's current
  SPM instructions when Fastlane is set up (§16).
- Cloud Functions (`onSwipeCreated`, `revenueCatWebhook`, `onMessageCreated`,
  `onPetPhotoUploaded`) are stubbed but not implemented.
