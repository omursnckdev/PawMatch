import * as admin from "firebase-admin";

/**
 * Sends a data+notification push to a single user by looking up their stored
 * FCM token. No-ops (and cleans up) when the token is missing or stale.
 */
export async function sendPushToUser(
  userId: string,
  notification: { title: string; body: string },
  data: { [key: string]: string }
): Promise<void> {
  const db = admin.firestore();
  const userSnap = await db.collection("users").doc(userId).get();
  const token = userSnap.get("fcmToken") as string | undefined;
  if (!token) {
    return;
  }

  try {
    await admin.messaging().send({
      token,
      notification,
      data,
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
      },
    });
  } catch (error: unknown) {
    // A messaging/registration-token-not-registered error means the token is
    // dead (app uninstalled, etc.) — clear it so we stop trying.
    const code = (error as { code?: string }).code ?? "";
    if (code.includes("registration-token-not-registered") || code.includes("invalid-argument")) {
      await db.collection("users").doc(userId).update({ fcmToken: admin.firestore.FieldValue.delete() });
    } else {
      console.error(`Failed to send push to ${userId}:`, error);
    }
  }
}
