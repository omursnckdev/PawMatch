import * as admin from "firebase-admin";

admin.initializeApp();

// Functions are added milestone-by-milestone per CLAUDE.md §7:
//   onSwipeCreated       — Milestone 4 (match detection)
//   revenueCatWebhook    — Milestone 5 (subscription entitlement sync)
//   onMessageCreated     — Milestone 4 (chat push + moderation pass)
//   onPetPhotoUploaded   — Milestone 4 (SafeSearch moderation)
