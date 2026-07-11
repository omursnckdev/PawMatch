import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { sendPushToUser } from "./fcm";
import { messageIsAbusive } from "./moderation";

/**
 * §7 items 3 & 5. On each new chat message: update the parent match's
 * lastMessage preview, run a moderation pass, and push the other participant
 * (deep-linking via the matchId data payload) unless they're actively viewing
 * that chat.
 */
export const onMessageCreated = functions.firestore
  .document("chats/{matchId}/messages/{messageId}")
  .onCreate(async (snapshot, context) => {
    const message = snapshot.data();
    if (!message) {
      return;
    }

    const matchId = context.params.matchId as string;
    const db = admin.firestore();
    const text: string = message.text ?? "";
    const senderId: string = message.senderId;

    // Moderation: flag repeat offenders for manual review; don't hard-block.
    if (messageIsAbusive(text)) {
      await db.collection("users").doc(senderId).set(
        {
          moderationFlagCount: admin.firestore.FieldValue.increment(1),
          lastModerationFlagAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    const matchRef = db.collection("matches").doc(matchId);
    const matchSnap = await matchRef.get();
    if (!matchSnap.exists) {
      return;
    }

    await matchRef.update({
      lastMessage: text.slice(0, 140),
      lastMessageAt: message.timestamp ?? admin.firestore.FieldValue.serverTimestamp(),
    });

    const userIds: string[] = matchSnap.get("userIds") ?? [];
    const recipientId = userIds.find((id) => id !== senderId);
    if (!recipientId) {
      return;
    }

    // Skip the push if the recipient blocked the sender (or vice versa), or is
    // currently viewing this conversation.
    const [recipientSnap, senderSnap] = await Promise.all([
      db.collection("users").doc(recipientId).get(),
      db.collection("users").doc(senderId).get(),
    ]);
    const recipientBlocked: string[] = recipientSnap.get("blockedUserIds") ?? [];
    const senderBlocked: string[] = senderSnap.get("blockedUserIds") ?? [];
    if (recipientBlocked.includes(senderId) || senderBlocked.includes(recipientId)) {
      return;
    }
    if (recipientSnap.get("activeChatId") === matchId) {
      return;
    }

    const senderName: string = senderSnap.get("displayName") ?? "Someone";
    await sendPushToUser(
      recipientId,
      { title: senderName, body: text.slice(0, 140) },
      { type: "message", matchId }
    );
  });
