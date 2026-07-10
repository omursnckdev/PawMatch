# PawMatch — Full Build Specification (for Claude Code)

> **How to use this document:** Save this file as `CLAUDE.md` in the root of a new,
> empty repository/Xcode project folder. Claude Code will automatically read it at
> the start of every session in that project. It contains everything needed to build
> PawMatch from an empty repo to an App Store submission-ready build — product
> requirements, architecture, data model, monetization, design system, and a
> phase-by-phase build plan with acceptance criteria. Do not skip the "Publish
> Readiness" and "Non-Negotiables" sections — App Store rejection is the most
> expensive mistake to make late.

---

## 1. Product Overview

**PawMatch** is a Tinder-style iOS app for pet owners. Users create a profile for
each of their pets (photos, species, breed, bio) and swipe on other pets nearby.
A match is created only when **both sides swipe right** (mutual match, exactly like
Tinder). Each pet profile is tagged with one or both purposes:

- **Playdate** — social/meetup matching
- **Breeding** — purebred/breeding-focused matching

Once matched, the two owners can chat in real time. Free users get limited daily
swipes and see a native ad card every 10 swipes; **PawMatch Plus** subscribers get
unlimited swipes and premium features (see §8).

---

## 2. Locked-In Product Decisions

These have already been decided with the product owner — do not re-litigate them,
just implement:

| Decision | Value |
|---|---|
| Matching model | Mutual swipe required (both like → match) |
| Match purposes | Playdate AND Breeding, both enabled, user picks per pet |
| Ad placement | Native ad card every 10th card in the swipe deck, free users only |
| Premium tier name | "PawMatch Plus" |
| Backend | Firebase (Auth, Firestore, Storage, Cloud Functions, FCM) |
| Subscriptions | RevenueCat wrapping StoreKit 2 |
| Ads | Google AdMob, native ad format |
| Platform | iOS only (SwiftUI, iOS 17+ minimum target) |
| Push notifications | Included in the initial build (new match + new message) |
| Minimum age | 18+ (age confirmation required at signup — see §10.6) |

If anything in this document seems to conflict with the above table, the table wins.

---

## 3. Complete Feature List

### Free tier
- Sign up / log in via Sign in with Apple or email+password
- Create 1 pet profile (multi-photo, species, breed, age, sex, bio, purpose tags)
- Swipe deck filtered by species + distance, each card shows distance to that pet
  (e.g. "3 km away")
- 15 swipes/day (resets at local midnight)
- Mutual matching
- **Superlike:** an extra-visible swipe direction (limited quantity/day) that places
  the swiper's pet at the top of the target's deck with a distinct badge — it signals
  strong interest but does **not** bypass the mutual-match requirement; the target
  still has to swipe right for a match to form.
- Real-time chat with matches; tapping a message notification deep-links straight
  into that conversation
- Push notifications for new matches and new messages
- Native ad card every 10 swipes
- Report / Block another user (required — see §10.5). Blocking is enforced
  server-side: a blocked user's pets are excluded from the blocker's deck query
  and vice versa, and neither can message the other even in an existing match.
- Delete account (required — see §10.5)

### PawMatch Plus (subscription)
- Unlimited swipes
- Multiple pet profiles per account
- Advanced filters: breed, age range, purpose
- Rewind last swipe
- See who liked you (before swiping)
- 1 monthly Boost (temporary priority placement in others' decks)
- No ads

---

## 4. Screen Map

```
Splash
 └─ Auth (Sign in with Apple / Email+Password, Sign Up / Log In toggle)
     └─ Age confirmation (first run only, 18+ gate)
     └─ Onboarding — Pet Profile Setup (multi-step: basics → photos → purpose → location permission)
         (each hard system permission prompt — location, notifications, ATT — is
         preceded by a friendly in-app "priming" screen explaining the benefit
         before the OS dialog fires, to improve opt-in rates)
         └─ Main Tab Bar
             ├─ Swipe Deck (card stack; ad card every 10th; empty-state when out of cards)
             │    └─ "It's a Match!" modal (on mutual swipe) → Send first message / Keep Swiping
             ├─ Matches (grid of mutual matches, tap → Chat)
             ├─ Chat (list of conversations → Chat Detail, real-time messages)
             ├─ Likes (Plus-only "who liked you" — paywall trigger if free)
             └─ Profile & Settings
                 ├─ Manage Pet Profiles (add/edit/delete, add second pet is Plus-gated)
                 ├─ Subscription management (current plan, Restore Purchases, manage/cancel link)
                 ├─ Notification preferences
                 ├─ Report a problem / Block list management
                 ├─ Terms of Service / Privacy Policy (must be reachable without an account)
                 └─ Delete Account (destructive, confirmation required)
Paywall (presented modally from: swipe limit hit, 2nd pet attempt, Likes tab, Rewind tap, Boost tap)
```

---

## 5. Technical Architecture

- **Pattern:** MVVM. `Views` are dumb SwiftUI views; `ViewModels` are
  `@MainActor final class ... ObservableObject`; `Services` are singletons wrapping
  Firebase/RevenueCat/AdMob SDK calls; `Models` are `Codable` structs matching
  Firestore documents via `@DocumentID` / `FirebaseFirestoreSwift` codable support.
- **Concurrency:** Swift concurrency (`async/await`) throughout; no completion-handler
  soup. Firestore listeners bridged into `AsyncStream` or Combine where live updates
  are needed (chat, swipe deck refresh, match list).
- **Dependency injection:** Services are accessed via `.shared` singletons for
  simplicity in v1, but every service should be defined behind a small protocol
  (e.g. `AuthServicing`, `FirestoreServicing`) so ViewModels can be unit tested with
  mock implementations.
- **App Check:** integrate Firebase App Check (DeviceCheck/App Attest provider) from
  Milestone 1 onward, enforced on Firestore, Storage, and callable/HTTPS Cloud
  Functions. Without this, the backend is wide open to scripted abuse (bots mass-
  creating fake accounts/swipes). Do not treat this as optional or "add later."
- **Crash monitoring:** integrate Firebase Crashlytics from Milestone 1 so crash
  data exists from the very first internal build, not bolted on before submission.
- **Folder structure:**
```
PawMatch/
  App/                  — App entry, AppDelegate, environment setup
  Models/                — Codable structs matching Firestore schema
  Services/              — Auth, Firestore, Storage, RevenueCat, AdMob, Notifications,
                            Geohash, AppCheck, Analytics, ImageCache
  ViewModels/
  Views/
    Auth/
    Onboarding/
    SwipeDeck/
    Matches/
    Chat/
    Profile/
    Paywall/
    Shared/              — reusable components (buttons, ad card, loading states)
  Resources/             — Assets.xcassets, Localizable.strings, PrivacyInfo.xcprivacy
CloudFunctions/           — separate Node/TypeScript project, deployed independently
```

---

## 6. Data Model (Firestore)

```
users/{userId}
  displayName: string
  email: string?
  authProvider: string
  isPremium: bool                  // synced from RevenueCat webhook, NOT client-writable
  dailySwipeCount: number
  lastSwipeResetDate: timestamp
  fcmToken: string?
  blockedUserIds: [string]
  createdAt: timestamp

pets/{petId}
  ownerId: string
  name: string
  species: string
  breed: string
  age: number
  sex: "male" | "female"
  purposes: ["playdate" | "breeding"]
  bio: string
  photoUrls: [string]
  latitude: number
  longitude: number
  geohash: string                  // see §6.1 — required for proximity queries
  boostedUntil: timestamp?         // set when Plus user uses monthly Boost
  createdAt: timestamp

swipes/{swipeId}
  swiperUserId: string
  swiperPetId: string
  targetPetId: string
  targetOwnerId: string
  direction: "like" | "pass" | "superlike"
  timestamp: timestamp

matches/{matchId}
  petIds: [petIdA, petIdB]
  userIds: [ownerIdA, ownerIdB]     // denormalized for security rules + queries
  purpose: "playdate" | "breeding"
  matchedAt: timestamp
  lastMessage: string?
  lastMessageAt: timestamp?

chats/{matchId}/messages/{messageId}
  senderId: string
  text: string
  timestamp: timestamp
  readBy: [string]
```

### 6.1 Proximity queries
Firestore cannot natively do radius queries on lat/lng. Store a **geohash** string
field on every pet document (computed client-side on save, e.g. via a small custom
geohash implementation or the `GeoFireUtils` companion library) and query using
geohash range bucketing for "pets within N km." Do not attempt naive
`whereField("latitude", isGreaterThan: ...)` — it does not produce correct results.

### 6.2 Required Firestore indexes
Composite index on `pets`: `species` (==) + `geohash` (range) + `purposes` (array-contains).
Composite index on `swipes`: `swiperPetId` (==) + `targetPetId` (==) — used by the
match-detection Cloud Function to check reciprocity.

### 6.3 Security rules
- `users/{uid}.isPremium` must be **server-write-only** (Cloud Functions / Admin SDK).
  Client writes to that specific field must be rejected in rules.
- `pets`: readable by any authenticated user, writable only by `ownerId`.
- `swipes`: creatable only where `swiperUserId == request.auth.uid`; never updatable.
- `matches`: writable only by Cloud Functions (`allow write: if false` client-side).
- `chats/{matchId}/messages`: readable/writable only by the two `userIds` on the
  parent match document (requires a `get()` lookup in the rule).
- All rules above assume **App Check enforcement is also enabled** on Firestore/
  Storage/Functions (see §5) — App Check and these ownership rules are
  complementary, not substitutes for each other.
- Deck queries must filter out any pet whose `ownerId` appears in either party's
  `blockedUserIds` array; do this client-side in the query construction (Firestore
  can't easily do a "not in a dynamic array on the other document" rule), and
  double-check it in the swipe-write rule so a blocked user cannot swipe on you
  even if their client is tampered with.

---

## 7. Cloud Functions

Implement as a separate TypeScript Cloud Functions project (`firebase-functions` +
`firebase-admin`).

1. **`onSwipeCreated`** (Firestore trigger on `swipes/{swipeId}` create)
   - Check if a reciprocal `like`/`superlike` swipe exists (`swiperPetId`/`targetPetId`
     reversed).
   - If yes: create a `matches` doc, then send an FCM push to both owners.
   - If no: no-op.

2. **`revenueCatWebhook`** (HTTPS function)
   - Verify the RevenueCat webhook signature/auth header.
   - On `INITIAL_PURCHASE` / `RENEWAL` / `UNCANCELLATION`: set `users/{uid}.isPremium = true`.
   - On `EXPIRATION` / `CANCELLATION` (if not renewed): set `isPremium = false`.
   - On `BILLING_ISSUE`: don't immediately revoke — RevenueCat/Apple grant a grace
     period; set a `users/{uid}.billingIssue = true` flag and keep `isPremium = true`
     until an actual `EXPIRATION` event arrives, so paying users in a grace period
     aren't cut off mid-cycle over a card decline.
   - This is the **only** writer of `isPremium` — never trust client-side entitlement
     checks for anything security-sensitive (only for UI gating).

3. **`onMessageCreated`** (Firestore trigger on `chats/{matchId}/messages/{messageId}`)
   - Update the parent `matches` doc's `lastMessage` / `lastMessageAt`.
   - Send an FCM push to the other participant (skip if they're actively viewing
     that chat — track via a `activeChatId` presence field, optional nicety). Include
     `matchId` in the notification's data payload so tapping it deep-links directly
     into that chat conversation rather than dropping the user on a generic screen.

4. **`onPetPhotoUploaded`** (Storage trigger, or called right after client-side
   upload completes)
   - Run the photo through **Cloud Vision SafeSearch** (or equivalent moderation
     API) to flag adult/violent/graphic content before the photo is attached to a
     live pet profile.
   - Flagged photos are held out of the public profile and the pet owner is
     notified to upload a different photo, rather than silently appearing in other
     users' decks.

5. **`onMessageCreated` moderation pass**: run outgoing message text through a
   lightweight profanity/abuse filter (or a moderation API) as part of the same
   function in item 3; flag repeated violations on a user for manual review rather
   than hard-blocking every message (avoid false-positive frustration for normal
   pet-related chatter).

6. **Daily swipe reset**: handle **client-side** for simplicity — compare
  `lastSwipeResetDate` to today's date on app launch/swipe attempt and reset
  `dailySwipeCount` to 0 if it's a new day. Avoids needing a scheduled function.

---

## 8. Monetization

### RevenueCat
- Entitlement identifier: `plus`
- Products (configure in App Store Connect + RevenueCat dashboard):
  - `pawmatch_plus_monthly` — suggested $4.99/mo (placeholder, confirm pricing)
  - `pawmatch_plus_annual` — suggested $29.99/yr
- Use RevenueCat's `Purchases.shared.getCustomerInfo()` / `.customerInfoStream` to
  gate client-side UI; the **source of truth for `isPremium` is the Firestore field
  set by the webhook** (§7, item 2), not the client SDK, to prevent tampering. If
  `billingIssue` is also true, show a gentle "update your payment method" banner
  rather than yanking Plus features away mid-grace-period.
- Include a StoreKit Configuration file for local Xcode testing without hitting
  App Store sandbox on every run.
- Settings screen must include a **"Restore Purchases"** button and a link to
  manage the subscription (deep link to `itms-apps://apps.apple.com/account/subscriptions`).

### AdMob
- Native ad format (`GADNativeAd`), styled to match the pet-card aesthetic (not a
  jarring banner).
- Insert exactly one ad card after every 10 swiped cards, **free users only** —
  check `isPremium` before inserting.
- Use test ad unit IDs during development; switch to production IDs only right
  before submission.
- Ads must be non-personalized unless the user grants App Tracking Transparency
  permission (see §10.4) — configure `GADRequestConfiguration` accordingly.

---

## 9. Design System

- **Theme:** warm, playful, pet-forward. Primary accent color: warm orange
  (`#FF9433`, already defined as `Color.pawOrange`). Rounded, friendly typography
  (`.rounded` SwiftUI font design for headings).
- **Iconography:** SF Symbols pet-related glyphs (`pawprint.fill`, `pawprint.circle.fill`)
  as placeholders; commission or generate a proper mascot/logo before submission.
- **Card component:** reusable `PetCardView` used identically in the swipe deck,
  match modal, and profile detail — build it once, reuse everywhere. Card overlay
  must show distance ("3 km away") and, when applicable, a distinct Superlike badge
  for cards that were superliked.
- **Permission priming screens:** a small reusable component (icon + one-sentence
  benefit + "Continue" button) shown immediately before each hard OS permission
  dialog (location, notifications, tracking) — do not fire system prompts cold on
  first launch.
- **Empty/loading/error states:** every list-driven screen (deck, matches, chat)
  needs an explicit empty state and a loading skeleton — do not ship blank screens.
- Support **Dark Mode** — use semantic colors (`Color(.secondarySystemBackground)`,
  etc.), avoid hardcoded white/black.
- Support **Dynamic Type** for accessibility — no fixed-size text that ignores the
  user's font size setting.

---

## 10. Non-Functional Requirements

### 10.1 Error handling
Every network call (Firestore, Storage, RevenueCat, AdMob) must handle failure
gracefully with a user-visible message — no silent failures, no force-unwraps on
network responses.

### 10.2 Offline behavior
Firestore's offline persistence should be enabled; the swipe deck and chat should
degrade gracefully (queued writes) rather than crash when offline.

### 10.3 Performance
- Paginate the swipe deck query (don't fetch the entire `pets` collection).
- Compress/resize photos client-side before upload to Firebase Storage (target
  ~1080px longest edge, JPEG ~70% quality) to control storage costs and load time.
- Use an image caching library (e.g. `Kingfisher` or `NukeUI`) rather than raw
  `AsyncImage` everywhere, so photos aren't re-downloaded every scroll/relaunch.
- Preload the next few cards' images in the swipe deck while the user is looking
  at the current card, so swiping never shows a blank/loading card.

### 10.4 Privacy & tracking
- Request **App Tracking Transparency** (`ATTrackingManager`) before requesting
  personalized ads.
- Include a `PrivacyInfo.xcprivacy` manifest covering Firebase, RevenueCat, and
  AdMob SDKs' data collection practices (required by Apple as of 2024 for apps
  using these SDKs).
- `Info.plist` usage strings required: `NSLocationWhenInUseUsageDescription`,
  `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (or
  `NSPhotoLibraryAddUsageDescription` if using `PHPickerViewController`, which
  needs no photo library permission at all — prefer `PHPickerViewController`),
  `NSUserTrackingUsageDescription`.

### 10.5 App Store policy compliance (Guideline 1.2 — User Generated Content)
Because PawMatch has chat and user-uploaded photos, Apple requires all of the
following or the app **will be rejected**:
- A mechanism to **report** objectionable content/users.
- A mechanism to **block** another user (and blocked users must disappear from
  the swipe deck and be unable to message the blocker).
- Published content standards the user agrees to at signup (Terms of Service).
- A functioning **Delete Account** flow (Settings → Delete Account), which must
  actually delete/anonymize the user's Firestore/Storage data, not just sign them
  out.
- Since Sign in with Apple is offered, the app already satisfies the "must offer
  Sign in with Apple if offering other third-party logins" rule — email/password
  is not a third-party login so this is already compliant, no further action needed.

### 10.6 Age gating
Add an 18+ confirmation step at signup (simple self-attestation checkbox/date-of-birth
is acceptable for this category; PawMatch is not aimed at minors given its
dating-app-adjacent matching mechanic).

### 10.7 Localization
Ship English first. Structure all user-facing strings through `Localizable.strings`
/ `String(localized:)` from day one so adding Turkish (or other languages) later is
a translation-only exercise, not a refactor.

### 10.8 Trust & safety
- Photos are screened via SafeSearch moderation before going live on a profile
  (§7, item 4); messages pass through a lightweight abuse/profanity filter (§7,
  item 5).
- Because "Breeding" is an explicit match purpose, add a short **Community
  Guidelines** page (linked from onboarding and Settings) covering responsible
  breeding practices and prohibiting solicitation of puppy-mill-style or otherwise
  irresponsible breeding — the user must acknowledge this alongside the Terms of
  Service at signup. This is both an animal-welfare responsibility and a
  reputational/App-Review risk-reduction measure.
- Report flow should let the reporter pick a reason (spam, inappropriate photo,
  harassment, animal welfare concern, other) rather than a free-text-only box —
  much easier to triage later.

### 10.9 Analytics
Integrate Firebase Analytics from Milestone 1 and log events across the funnel
from day one rather than retrofitting them before launch: `sign_up_completed`,
`pet_profile_created`, `swipe_performed` (with direction), `match_created`,
`message_sent`, `paywall_viewed`, `paywall_purchase_completed`,
`paywall_dismissed`. This is the data needed to see where users drop off in
onboarding/swiping/paywall — much harder to reconstruct after launch than to log
as each feature is built.

---

## 11. Testing Strategy

- **Unit tests (XCTest):** ViewModels (`AuthViewModel`, swipe deck logic, paywall
  gating logic) tested against protocol-mocked services — no live Firebase calls
  in unit tests.
- **Firebase Local Emulator Suite:** use for integration testing of Firestore rules
  and Cloud Functions locally before every deploy — do not test security rules
  against production.
- **UI tests (XCUITest):** cover the critical path — sign up → create pet profile
  → swipe → mutual match → send message — and the paywall trigger/purchase flow
  using the StoreKit Configuration file's test transactions.

---

## 12. Build Milestones

Each milestone below must be fully working and manually verified against its
acceptance criteria before starting the next one.

### Milestone 1 — Foundation & Auth
- Xcode project created, Firebase SDKs added, `GoogleService-Info.plist` wired.
- Firebase App Check, Crashlytics, and Analytics integrated from the start (§5, §10.9).
- Sign in with Apple + email/password both working; `users/{uid}` doc created on
  first sign-in.
- **Acceptance:** fresh install → sign up → app relaunch stays signed in → sign out
  works; a test crash appears in the Crashlytics dashboard; a test event appears
  in Analytics.

### Milestone 2 — Pet Profiles
- Multi-step profile creation (basics, photo upload via `PHPickerViewController`
  → Storage, purpose tags, location permission + geohash computed on save).
- Edit/delete own pet profile.
- **Acceptance:** a new user with 0 pets is routed into profile setup; profile
  persists and photos load correctly across app relaunch.

### Milestone 3 — Swipe Deck
- Deck query filtered by species/purpose/geohash-proximity, excludes already-swiped
  pets and the current user's own pets.
- Swipe gestures (drag + button fallback), writes to `swipes`.
- Daily swipe counter + limit enforcement for free users.
- **Acceptance:** swiping decrements the daily counter correctly and resets at
  midnight; hitting the limit shows the paywall.

### Milestone 4 — Matching & Chat
- `onSwipeCreated` Cloud Function deployed and creating `matches` correctly.
- "It's a Match!" modal on mutual swipe.
- Real-time chat with FCM push notifications for new matches/messages, tapping a
  notification deep-links into the correct conversation.
- Photo moderation (`onPetPhotoUploaded`) and message moderation pass wired in.
- Block flow fully enforced: blocked pets excluded from deck queries in both
  directions, blocked users cannot message each other even in an existing match.
- **Acceptance:** two test accounts swiping right on each other produces a match
  visible to both within seconds, and messages appear in real time on both devices;
  blocking one account from the other immediately removes them from each other's
  deck and chat.

### Milestone 5 — Monetization
- RevenueCat SDK integrated, paywall UI built, entitlement gating wired to all
  Plus features (unlimited swipes, multi-pet, filters, rewind, who-liked-you, boost).
- `revenueCatWebhook` deployed and correctly flipping `isPremium`.
- AdMob native ad card inserted every 10 swipes for free users only.
- **Acceptance:** a sandbox purchase flips `isPremium` within a few seconds and
  immediately removes ads/limits in the UI; Restore Purchases works on a second
  device with the same Apple ID.

### Milestone 6 — Publish Readiness
- Report/Block flow fully functional (§10.5).
- Delete Account flow fully functional, actually deletes data.
- ATT prompt + `PrivacyInfo.xcprivacy` manifests in place.
- Community Guidelines page live and acknowledged at signup alongside Terms of
  Service (§10.8).
- App Check enforced in production mode (not just debug/test tokens).
- App icon, launch screen, and App Store screenshots for all required device sizes.
- Terms of Service + Privacy Policy pages reachable pre-signup.
- Firestore security rules deployed and verified against the emulator test suite
  (§11), not just "works in my testing."
- Fastlane configured for automated build/TestFlight upload (§16).
- TestFlight build uploaded and internally tested end-to-end.
- **Acceptance:** run through the entire App Store Review checklist (§13) with
  every item checked off before submitting.

---

## 13. Publish Readiness Checklist

- [ ] App icon (all required sizes) + launch screen
- [ ] Screenshots for all currently-required App Store Connect device sizes
- [ ] Privacy Policy URL (live, publicly reachable) + Terms of Service
- [ ] App Privacy "Nutrition Label" answers in App Store Connect match what the
      app actually collects (location, photos, user content, identifiers for ads)
- [ ] Age rating questionnaire completed accurately (UGC + chat + dating-adjacent
      matching typically lands in a higher age bracket — answer honestly)
- [ ] Report + Block functionality live and tested
- [ ] Delete Account functionality live and tested (actually removes data)
- [ ] Sign in with Apple present and working (already satisfied by design)
- [ ] Restore Purchases button present and working
- [ ] Subscription terms disclosed on the paywall (price, duration, auto-renewal,
      cancellation instructions) per Apple's subscription guidelines
- [ ] `PrivacyInfo.xcprivacy` present for Firebase, RevenueCat, and AdMob
- [ ] App Tracking Transparency prompt implemented correctly
- [ ] Firestore security rules deployed (not left in test/open mode)
- [ ] Firebase App Check enforced in production mode on Firestore/Storage/Functions
- [ ] Crashlytics live and confirmed reporting (test crash visible in dashboard)
- [ ] Photo moderation (SafeSearch) and message moderation pass confirmed working
- [ ] Community Guidelines page live and acknowledged at signup
- [ ] Blocked-user enforcement verified bidirectionally (deck + chat)
- [ ] Crash-free manual run-through of the full critical path on a physical device
- [ ] TestFlight build tested by at least one external tester besides the developer
- [ ] Fastlane pipeline successfully produces a TestFlight build end-to-end

---

## 14. Engineering Conventions

- Swift API Design Guidelines naming throughout; no abbreviations in public APIs.
- No force-unwraps (`!`) outside of tests and IBOutlet-style guaranteed-non-nil
  cases; use `guard let` / `if let` / nil-coalescing.
- Every `Service` exposed via a protocol for testability, even though there's one
  concrete implementation in v1.
- Secrets (API keys, RevenueCat public key) go in an untracked `Secrets.xcconfig`
  file, never hardcoded in source or committed to git — provide a
  `Secrets.xcconfig.example` template instead.
- Commit in small, logical units per feature/fix, not one giant commit per milestone.

---

## 16. CI/CD & Release Automation

"Publish-ready" means the release **pipeline** is ready too, not just the app:

- Set up **Fastlane** (`fastlane match` for code signing, a `beta` lane that bumps
  build number, builds, and uploads to TestFlight in one command).
- Store signing certificates/profiles via `fastlane match` (git-crypt or a private
  repo), never committed in plaintext.
- A single command (e.g. `fastlane beta`) should take a clean checkout from zero
  to a new TestFlight build, so releases aren't a manual Xcode Organizer ritual.
- Optional but recommended: wire this into a CI runner (GitHub Actions with a
  macOS runner) so every merge to `main` can produce a TestFlight build
  automatically.

---

## 17. Definition of Done

PawMatch is "done" for v1 submission when every checkbox in §13 is checked, every
milestone in §12 has met its acceptance criteria on a physical device (not just
simulator), a fresh TestFlight installer can go from zero to sending a chat
message with a mutual match without hitting a single crash, dead-end screen, or
missing empty/error state, and a single Fastlane command can reproduce that
TestFlight build from a clean checkout.
