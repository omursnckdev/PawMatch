import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

/**
 * §7 item 2. The **only** writer of `users/{uid}.isPremium`. RevenueCat posts
 * subscription lifecycle events here; we translate them into the entitlement
 * flag the app trusts.
 *
 * Auth: RevenueCat sends the value configured as the webhook's Authorization
 * header. Set it with:
 *   firebase functions:secrets:set REVENUECAT_WEBHOOK_AUTH
 * and configure the same value in the RevenueCat dashboard.
 */
export const revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const expected = process.env.REVENUECAT_WEBHOOK_AUTH;
  if (!expected || req.header("Authorization") !== expected) {
    res.status(401).send("Unauthorized");
    return;
  }

  const event = req.body?.event;
  const appUserId: string | undefined = event?.app_user_id;
  const type: string | undefined = event?.type;
  if (!appUserId || !type) {
    res.status(400).send("Bad Request");
    return;
  }

  const db = admin.firestore();
  const userRef = db.collection("users").doc(appUserId);

  try {
    switch (type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "UNCANCELLATION":
      case "PRODUCT_CHANGE":
        await userRef.set({ isPremium: true, billingIssue: false }, { merge: true });
        break;

      case "EXPIRATION":
      case "CANCELLATION":
        // CANCELLATION means auto-renew is off but access continues until the
        // period ends; RevenueCat still sends EXPIRATION at the actual end.
        // Only EXPIRATION revokes access here.
        if (type === "EXPIRATION") {
          await userRef.set({ isPremium: false, billingIssue: false }, { merge: true });
        }
        break;

      case "BILLING_ISSUE":
        // Don't revoke during the grace period — just flag it (§7 item 2).
        await userRef.set({ billingIssue: true }, { merge: true });
        break;

      default:
        // Unhandled event types are acknowledged so RevenueCat stops retrying.
        break;
    }
    res.status(200).send("OK");
  } catch (error) {
    console.error(`revenueCatWebhook failed for ${appUserId} (${type}):`, error);
    res.status(500).send("Internal Error");
  }
});
