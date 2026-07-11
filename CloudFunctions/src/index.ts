import * as admin from "firebase-admin";

admin.initializeApp();

// Each function lives in its own module and is re-exported here (§7).
export { onSwipeCreated } from "./onSwipeCreated";
export { onMessageCreated } from "./onMessageCreated";
export { onPetPhotoUploaded } from "./onPetPhotoUploaded";
export { revenueCatWebhook } from "./revenueCatWebhook";
export { onAccountDeletionRequested } from "./onAccountDeletionRequested";
