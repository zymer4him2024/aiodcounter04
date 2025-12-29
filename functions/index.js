const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();
const db = admin.firestore();

/**
 * Register a Raspberry Pi device
 * POST /registerDevice
 * Headers: x-enroll-token: <enrollment-token>
 * Body: { siteId: string, cameraId: string }
 */
exports.registerDevice = functions.https.onRequest(async (req, res) => {
  // Set CORS headers
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, x-enroll-token");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  if (req.method !== "POST") {
    return res.status(405).json({
      ok: false,
      errorCode: "METHOD_NOT_ALLOWED",
      message: "Only POST method is allowed",
    });
  }

  try {
    // Read enrollment token from header
    const enrollToken = req.headers["x-enroll-token"];
    if (!enrollToken) {
      return res.status(401).json({
        ok: false,
        errorCode: "MISSING_TOKEN",
        message: "Missing x-enroll-token header",
      });
    }

    // Read siteId and cameraId from body
    const {siteId, cameraId} = req.body;
    if (!siteId || !cameraId) {
      return res.status(400).json({
        ok: false,
        errorCode: "MISSING_PARAMS",
        message: "Missing siteId or cameraId in request body",
      });
    }

    // Hash the enrollment token for lookup
    const tokenHash = crypto
        .createHash("sha256")
        .update(enrollToken)
        .digest("hex");

    // Validate enrollment token using transaction
    const tokenRef = db.collection("enrollTokens").doc(tokenHash);
    const deviceId = crypto
        .createHash("sha256")
        .update(`${siteId}:${cameraId}`)
        .digest("hex")
        .slice(0, 24);

    let tokenData;
    let tenantId;
    let siteIdFromToken;

    // Transaction to validate and increment token usage
    try {
      await db.runTransaction(async (transaction) => {
        const tokenDoc = await transaction.get(tokenRef);
        if (!tokenDoc.exists) {
          throw new Error("TOKEN_NOT_FOUND");
        }

        tokenData = tokenDoc.data();
        tenantId = tokenData.tenantId;
        siteIdFromToken = tokenData.siteId;

        // Validate token
        if (!tokenData.active) {
          throw new Error("TOKEN_INACTIVE");
        }

        if (tokenData.expiresAt && tokenData.expiresAt.toMillis() < Date.now()) {
          throw new Error("TOKEN_EXPIRED");
        }

        if (tokenData.maxUses && tokenData.uses >= tokenData.maxUses) {
          throw new Error("TOKEN_MAX_USES_EXCEEDED");
        }

        // Validate siteId matches token's siteId
        if (siteIdFromToken && siteIdFromToken !== siteId) {
          throw new Error("SITE_ID_MISMATCH");
        }

        // Increment uses
        transaction.update(tokenRef, {
          uses: admin.firestore.FieldValue.increment(1),
          lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      const errorMessage = error.message;
      if (errorMessage === "TOKEN_NOT_FOUND") {
        return res.status(401).json({
          ok: false,
          errorCode: "TOKEN_NOT_FOUND",
          message: "Invalid enrollment token",
        });
      } else if (errorMessage === "TOKEN_INACTIVE") {
        return res.status(403).json({
          ok: false,
          errorCode: "TOKEN_INACTIVE",
          message: "Enrollment token is inactive",
        });
      } else if (errorMessage === "TOKEN_EXPIRED") {
        return res.status(403).json({
          ok: false,
          errorCode: "TOKEN_EXPIRED",
          message: "Enrollment token has expired",
        });
      } else if (errorMessage === "TOKEN_MAX_USES_EXCEEDED") {
        return res.status(429).json({
          ok: false,
          errorCode: "TOKEN_MAX_USES_EXCEEDED",
          message: "Enrollment token has reached maximum uses",
        });
      } else if (errorMessage === "SITE_ID_MISMATCH") {
        return res.status(403).json({
          ok: false,
          errorCode: "SITE_ID_MISMATCH",
          message: "Site ID does not match enrollment token",
        });
      } else {
        console.error("Transaction error:", error);
        return res.status(500).json({
          ok: false,
          errorCode: "INTERNAL_ERROR",
          message: "Failed to validate enrollment token",
        });
      }
    }

    // Generate API key
    const apiKey = `sk_live_${crypto.randomBytes(32).toString("hex")}`;
    const apiKeyHash = crypto
        .createHash("sha256")
        .update(apiKey)
        .digest("hex");
    const keyId = crypto.randomBytes(16).toString("hex");

    // Create/update device document
    const deviceRef = db.collection("devices").doc(deviceId);
    await deviceRef.set({
      deviceId,
      tenantId,
      siteId,
      cameraId,
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "active",
    }, {merge: true});

    // Store API key hash
    const apiKeyRef = db.collection("apiKeys").doc(keyId);
    await apiKeyRef.set({
      keyId,
      keyHash: apiKeyHash,
      tenantId,
      siteId,
      deviceId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUsedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "active",
    });

    // Return success response
    return res.status(200).json({
      ok: true,
      deviceId,
      apiKey,
      tenantId,
      siteId,
    });
  } catch (error) {
    console.error("registerDevice error:", error);
    return res.status(500).json({
      ok: false,
      errorCode: "INTERNAL_ERROR",
      message: "An internal error occurred",
    });
  }
});

