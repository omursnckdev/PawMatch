import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";

/**
 * §10.5 / §13. Callable invoked by the client's "Delete Account" flow. Actually
 * removes the user's data (not just sign-out): their pets + photos, their
 * swipes, their matches and the chat messages under them, the user document,
 * and finally the Firebase Auth record.
 */
export const onAccountDeletionRequested = functions.https.onCall(async (_data, context) => {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "You must be signed in.");
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  // 1. Pets owned by the user + their Storage photos.
  const pets = await db.collection("pets").where("ownerId", "==", uid).get();
  await Promise.all(
    pets.docs.map(async (petDoc) => {
      await bucket.deleteFiles({ prefix: `petPhotos/${uid}/${petDoc.id}/` }).catch(() => undefined);
      await petDoc.ref.delete();
    })
  );

  // 2. Swipes made by the user.
  await deleteQueryBatch(db.collection("swipes").where("swiperUserId", "==", uid));

  // 3. Matches involving the user, and their chat message subcollections.
  const matches = await db.collection("matches").where("userIds", "array-contains", uid).get();
  await Promise.all(
    matches.docs.map(async (matchDoc) => {
      await deleteQueryBatch(db.collection("chats").doc(matchDoc.id).collection("messages"));
      await matchDoc.ref.delete();
    })
  );

  // 4. The user document, then the auth record.
  await db.collection("users").doc(uid).delete();
  await admin.auth().deleteUser(uid);

  return { deleted: true };
});

/** Deletes every document matched by a query in batches of 300. */
async function deleteQueryBatch(query: admin.firestore.Query): Promise<void> {
  const db = admin.firestore();
  while (true) {
    const snapshot = await query.limit(300).get();
    if (snapshot.empty) {
      return;
    }
    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    if (snapshot.size < 300) {
      return;
    }
  }
}
