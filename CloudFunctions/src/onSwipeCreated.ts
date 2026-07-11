import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import { sendPushToUser } from "./fcm";

/**
 * §7 item 1. On each new swipe, check for a reciprocal like/superlike. If one
 * exists, create the match (idempotently) and push both owners.
 */
export const onSwipeCreated = functions.firestore
  .document("swipes/{swipeId}")
  .onCreate(async (snapshot) => {
    const swipe = snapshot.data();
    if (!swipe || swipe.direction === "pass") {
      return;
    }

    const db = admin.firestore();

    // Reciprocal swipe: the target's pet swiped right on the swiper's pet.
    const reciprocal = await db
      .collection("swipes")
      .where("swiperPetId", "==", swipe.targetPetId)
      .where("targetPetId", "==", swipe.swiperPetId)
      .where("direction", "in", ["like", "superlike"])
      .limit(1)
      .get();

    if (reciprocal.empty) {
      return;
    }

    const petIdA: string = swipe.swiperPetId;
    const petIdB: string = swipe.targetPetId;
    const ownerA: string = swipe.swiperUserId;
    const ownerB: string = swipe.targetOwnerId;

    // Deterministic id from the sorted pet pair so a match can never be created
    // twice regardless of which side's swipe lands second.
    const matchId = [petIdA, petIdB].sort().join("_");
    const matchRef = db.collection("matches").doc(matchId);

    const created = await db.runTransaction(async (tx) => {
      const existing = await tx.get(matchRef);
      if (existing.exists) {
        return false;
      }

      const purpose = await resolveSharedPurpose(db, petIdA, petIdB);
      tx.set(matchRef, {
        petIds: [petIdA, petIdB],
        userIds: [ownerA, ownerB],
        purpose,
        matchedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastMessage: null,
        lastMessageAt: null,
      });
      return true;
    });

    if (!created) {
      return;
    }

    await Promise.all([
      sendPushToUser(
        ownerA,
        { title: "It's a match! 🐾", body: "You and another pet parent liked each other." },
        { type: "match", matchId }
      ),
      sendPushToUser(
        ownerB,
        { title: "It's a match! 🐾", body: "You and another pet parent liked each other." },
        { type: "match", matchId }
      ),
    ]);
  });

/**
 * Picks a match purpose shared by both pets, preferring "breeding" only when
 * both explicitly list it; otherwise falls back to "playdate".
 */
async function resolveSharedPurpose(
  db: admin.firestore.Firestore,
  petIdA: string,
  petIdB: string
): Promise<string> {
  const [petA, petB] = await Promise.all([
    db.collection("pets").doc(petIdA).get(),
    db.collection("pets").doc(petIdB).get(),
  ]);
  const purposesA: string[] = petA.get("purposes") ?? [];
  const purposesB: string[] = petB.get("purposes") ?? [];
  const shared = purposesA.filter((p) => purposesB.includes(p));

  if (shared.includes("breeding") && !shared.includes("playdate")) {
    return "breeding";
  }
  return shared.includes("playdate") ? "playdate" : shared[0] ?? "playdate";
}
