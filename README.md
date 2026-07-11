# PawMatch

Tinder-style iOS app for pet owners (playdates + breeding matches). Full product
spec, architecture, data model, and build plan live in [`CLAUDE.md`](./CLAUDE.md).

## Status

**All six milestones scaffolded** (Foundation & Auth; Pet Profiles; Swipe Deck;
Matching & Chat; Monetization; Publish Readiness). This was built in a Linux
container with **no Xcode/Swift toolchain available**, so the code has been
written carefully against the Firebase/SwiftUI/RevenueCat/AdMob APIs but has
**not been compiled or run**. The first thing to do on a Mac is `xcodegen
generate`, open it in Xcode, and fix whatever the compiler finds. Treat this as
a thorough first draft, not a verified build.

### ⚠️ Read before building
- **AdMob symbol names**: `AdManager` / `NativeAdCardView` use the *un-prefixed*
  Google Mobile Ads Swift API (`NativeAd`, `AdLoader`, `MobileAds`, `Request`).
  Depending on the exact SDK version SPM resolves, you may need the `GAD`-prefixed
  names (`GADNativeAd`, etc.). Adjust to match the version that resolves.
- **RevenueCat `Package`** can't be constructed in unit tests, so
  `PaywallViewModel.purchase(_:)` isn't directly unit-tested (the surrounding
  logic is). Verify the purchase path manually with the StoreKit config file.
- Everything else is covered under "Manual steps before submission" below.

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

### Milestone 3 — Swipe Deck
- `MainTabView` 5-tab shell (§4); Swipe and Profile tabs functional, Matches /
  Chat / Likes are placeholders for Milestones 4–5.
- `DeckService` geohash-proximity query via `GeoFireUtils` bounds, parallel
  per-bound queries merged and filtered to the true radius (§6.1); deck excludes
  the user's own pets, already-swiped pets, and blocked owners (§6.3).
- `SwipeDeckView` card stack with drag-to-swipe (like/pass), a superlike button,
  and button fallbacks; next card previewed underneath.
- `DailySwipeCounter` (pure, fully unit-tested) enforces the 15/day free limit
  with local-midnight reset (§7 item 6); premium bypasses. Superlikes have their
  own daily cap. Hitting a limit presents the paywall instead of swiping.
- `PaywallView` benefits screen with the purchase button disabled (real
  RevenueCat purchase + subscription terms land in Milestone 5) — already logs
  `paywall_viewed` / `paywall_dismissed`.
- Incoming-superlike cards float to the top of the deck with the Superlike badge.
- Unit tests for `DailySwipeCounter` and `SwipeDeckViewModel` (exclusions,
  sorting, limit→paywall, midnight reset, premium bypass).

### Milestone 4 — Matching & Chat
- Cloud Functions: `onSwipeCreated` (idempotent match detection via a
  deterministic match id + FCM), `onMessageCreated` (lastMessage update,
  profanity moderation pass, deep-link push, block-aware), `onPetPhotoUploaded`
  (Cloud Vision SafeSearch).
- `MatchService`/`ChatService` bridge Firestore listeners into `AsyncStream`;
  Matches grid, Chat conversation list, real-time `ChatDetailView`.
- "It's a Match!" modal via `MatchObserver`; FCM token sync + notification-tap
  deep-link into the conversation.
- Block + report (fixed-reason `ReportSheet`) with server-side rule enforcement
  and client filtering. Notification permission priming.

### Milestone 5 — Monetization
- RevenueCat `PurchaseService`; `EntitlementManager` reads `isPremium` from the
  Firestore field the `revenueCatWebhook` writes (source of truth), with an
  optimistic unlock on purchase. `PaywallView` shows real offerings, purchase,
  Restore Purchases, and subscription-terms disclosure.
- Plus gating: unlimited swipes, second pet, "who liked you" Likes tab,
  billing-issue grace banner.
- AdMob native ad card every 10 swipes for free users (`AdManager` +
  `NativeAdCardView`), non-personalized unless ATT is granted.

### Milestone 6 — Publish Readiness
- Delete Account flow (`AccountService` → `onAccountDeletionRequested` callable
  that actually deletes pets/photos/swipes/matches/chats/user/auth).
- ATT prompt with priming (§10.4); expanded `PrivacyInfo.xcprivacy`.
- Terms / Privacy reachable pre-signup (AuthView) and acknowledged with
  Community Guidelines at signup (age gate).
- Fastlane `beta` lane (§16), GitHub Actions CI, App Check App Attest in release.

Unit tests across `AuthViewModel`, `PetProfileViewModel`, `HomeViewModel`,
`DailySwipeCounter`, `SwipeDeckViewModel`, `ChatDetailViewModel`,
`MatchesViewModel`, and `DeleteAccountViewModel` — all against protocol-mocked
services (no live Firebase).

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

4b. Deploy Cloud Functions: `cd CloudFunctions && npm install && npm run deploy`.
    Set the RevenueCat webhook secret: `firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH`
    and point the RevenueCat dashboard webhook at the deployed `revenueCatWebhook`
    URL with that same Authorization value.
9. Deploy indexes: `firebase deploy --only firestore:indexes`.
10. `bundle install` then `fastlane beta` to produce a TestFlight build (§16).

## Manual steps before submission (can't be done in this environment)

These need Xcode, an Apple Developer account, or live dashboards:

- **Compile & fix**: no code here has been through a Swift compiler — expect to
  fix API/signature mismatches (especially the AdMob symbol names noted above).
- **App icon**: `AppIcon.appiconset` has only the JSON, no 1024×1024 art (§9/§13).
- **Crashlytics dSYM upload**: add the Crashlytics run-script build phase per
  Firebase's current SPM instructions (removed from `project.yml` to avoid a
  broken path; wire it up in Xcode or Fastlane).
- **App Check enforcement**: the client uses App Attest in release; you must also
  *enforce* App Check on Firestore/Storage/Functions in the Firebase console (§13).
- **RevenueCat / AdMob dashboards**: create products (`pawmatch_plus_monthly`,
  `pawmatch_plus_annual`), the `plus` entitlement, and production ad units; switch
  `AdManager` off the test ad unit for release (it already does this via `#if DEBUG`).
- **StoreKit config file**: add one for local purchase testing (§8).
- **Legal pages**: host real Terms / Privacy / Community Guidelines at the URLs in
  `LegalLinks.swift` (§13).
- **App Privacy answers** in App Store Connect must match `PrivacyInfo.xcprivacy`.
- **Emulator rule tests** (§11): run the Firebase Local Emulator Suite against
  `firestore.rules` before deploying.
