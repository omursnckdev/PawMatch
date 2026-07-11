import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import vision from "@google-cloud/vision";

const visionClient = new vision.ImageAnnotatorClient();

/**
 * §7 item 4. When a pet photo lands in Storage, run Cloud Vision SafeSearch.
 * If it's likely adult/violent/racy, delete the object and flag the pet so the
 * owner is asked to upload a different photo — rather than letting it appear in
 * other users' decks.
 *
 * Storage layout: petPhotos/{ownerId}/{petId}/{fileName}
 */
export const onPetPhotoUploaded = functions.storage
  .object()
  .onFinalize(async (object) => {
    const filePath = object.name ?? "";
    if (!filePath.startsWith("petPhotos/")) {
      return;
    }

    const parts = filePath.split("/");
    if (parts.length < 4) {
      return;
    }
    const petId = parts[2];

    const gcsUri = `gs://${object.bucket}/${filePath}`;
    const [result] = await visionClient.safeSearchDetection(gcsUri);
    const safe = result.safeSearchAnnotation;
    if (!safe) {
      return;
    }

    const flagged = isLikely(safe.adult) || isLikely(safe.violence) || isLikely(safe.racy);
    if (!flagged) {
      return;
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket(object.bucket);

    // Remove the offending object and record a moderation flag on the pet. The
    // client can compute the download URL from the path to prune it from
    // photoUrls; we also surface a flag so the UI can prompt for a new photo.
    await Promise.all([
      bucket.file(filePath).delete().catch((error) => {
        console.error(`Failed to delete flagged photo ${filePath}:`, error);
      }),
      db.collection("pets").doc(petId).set(
        {
          photoModerationFlagged: true,
          photoModerationFlaggedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      ),
    ]);
  });

type Likelihood =
  | "UNKNOWN"
  | "VERY_UNLIKELY"
  | "UNLIKELY"
  | "POSSIBLE"
  | "LIKELY"
  | "VERY_LIKELY"
  | null
  | undefined;

function isLikely(value: Likelihood): boolean {
  return value === "LIKELY" || value === "VERY_LIKELY";
}
