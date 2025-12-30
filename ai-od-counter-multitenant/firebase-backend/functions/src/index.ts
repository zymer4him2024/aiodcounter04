import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";
import axios from "axios";

admin.initializeApp();
const db = admin.firestore();

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Verify user is authenticated
 */
function verifyAuth(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "User must be authenticated"
    );
  }
  return context.auth.uid;
}

/**
 * Verify user has superadmin role
 */
function verifySuperAdmin(context: functions.https.CallableContext): string {
  const uid = verifyAuth(context);
  const role = context.auth?.token.role;
  
  if (role !== "superadmin") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only superadmins can perform this action"
    );
  }
  
  return uid;
}

/**
 * Generate random ID with prefix
 */
function generateId(prefix: string): string {
  const random = crypto.randomBytes(8).toString("hex").toUpperCase();
  return `${prefix}_${random}`;
}

/**
 * Generate random token with prefix
 */
function generateToken(prefix: string, length: number = 16): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let token = prefix + "_";
  const randomBytes = crypto.randomBytes(length);
  
  for (let i = 0; i < length; i++) {
    token += chars[randomBytes[i] % chars.length];
  }
  
  return token;
}

// ============================================================================
// AUTHENTICATION FUNCTIONS
// ============================================================================

/**
 * Create first superadmin (called on first Google sign-in)
 */
export const createFirstSuperadmin = functions.https.onCall(
  async (data, context) => {
    try {
      const { uid, email, name, photoURL } = data;

      // Verify this is being called by an authenticated user
      if (!context.auth || context.auth.uid !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Invalid authentication"
        );
      }

      // Check if any superadmins exist
      const existingSuperadmins = await db.collection("superadmins").limit(1).get();
      if (!existingSuperadmins.empty) {
        throw new functions.https.HttpsError(
          "already-exists",
          "Superadmin already exists"
        );
      }

      // Create superadmin document
      await db.collection("superadmins").doc(uid).set({
        uid,
        email,
        name,
        photoURL: photoURL || null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Set custom claims
      await admin.auth().setCustomUserClaims(uid, {
        role: "superadmin",
      });

      functions.logger.info(`First superadmin created: ${email}`);

      return { success: true, message: "Superadmin created successfully" };
    } catch (error: any) {
      functions.logger.error("Error creating first superadmin:", error);
      throw error;
    }
  }
);

/**
 * Create subadmin (superadmin only)
 */
export const createSubadmin = functions.https.onCall(async (data, context) => {
  try {
    const uid = verifySuperAdmin(context);
    const { email, name, companyName } = data;

    // Validate input
    if (!email || !name || !companyName) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Email, name, and company name are required"
      );
    }

    // Create auth user (they'll sign in with Google)
    // For now, we'll just create the invite - they sign in with Google later
    // In production, you'd send an email invite

    // Create subadmin document
    const subadminRef = db.collection("subadmins").doc();
    await subadminRef.set({
      uid: subadminRef.id,
      email,
      name,
      companyName,
      assignedSites: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
    });

    functions.logger.info(`Subadmin created: ${email} by ${uid}`);

    return {
      success: true,
      subadminId: subadminRef.id,
      message: "Subadmin created successfully",
    };
  } catch (error: any) {
    functions.logger.error("Error creating subadmin:", error);
    throw error;
  }
});

/**
 * Create viewer (superadmin only)
 */
export const createViewer = functions.https.onCall(async (data, context) => {
  try {
    const uid = verifySuperAdmin(context);
    const { email, name, assignedCameras } = data;

    if (!email || !name) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Email and name are required"
      );
    }

    const viewerRef = db.collection("viewers").doc();
    await viewerRef.set({
      uid: viewerRef.id,
      email,
      name,
      assignedCameras: assignedCameras || [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
    });

    functions.logger.info(`Viewer created: ${email} by ${uid}`);

    return {
      success: true,
      viewerId: viewerRef.id,
      message: "Viewer created successfully",
    };
  } catch (error: any) {
    functions.logger.error("Error creating viewer:", error);
    throw error;
  }
});

// ============================================================================
// SITE MANAGEMENT
// ============================================================================

/**
 * Create site (superadmin only)
 */
export const createSite = functions.https.onCall(async (data, context) => {
  try {
    const uid = verifySuperAdmin(context);
    const { name, location, subadminId } = data;

    if (!name || !location || !subadminId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Name, location, and subadmin ID are required"
      );
    }

    // Verify subadmin exists
    const subadminDoc = await db.collection("subadmins").doc(subadminId).get();
    if (!subadminDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Subadmin not found"
      );
    }

    // Create site
    const siteRef = db.collection("sites").doc();
    const siteId = siteRef.id;

    await siteRef.set({
      id: siteId,
      name,
      location,
      subadminId,
      status: "active",
      assignedCameras: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: uid,
    });

    // Add site to subadmin's assignedSites
    await db.collection("subadmins").doc(subadminId).update({
      assignedSites: admin.firestore.FieldValue.arrayUnion(siteId),
    });

    functions.logger.info(`Site created: ${name} (${siteId}) by ${uid}`);

    return {
      success: true,
      siteId,
      message: "Site created successfully",
    };
  } catch (error: any) {
    functions.logger.error("Error creating site:", error);
    throw error;
  }
});

// ============================================================================
// CAMERA MANAGEMENT
// ============================================================================

/**
 * Approve camera from pending queue (superadmin only)
 */
export const approveCamera = functions.https.onCall(async (data, context) => {
  try {
    const uid = verifySuperAdmin(context);
    const { deviceId, cameraName, siteId, subadminId } = data;

    if (!deviceId || !cameraName || !siteId || !subadminId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "All fields are required"
      );
    }

    // Get pending camera
    const pendingCameraDoc = await db
      .collection("pending_cameras")
      .doc(deviceId)
      .get();

    if (!pendingCameraDoc.exists) {
      throw new functions.https.HttpsError(
        "not-found",
        "Pending camera not found"
      );
    }

    const pendingCamera = pendingCameraDoc.data()!;
    const cameraId = generateId("CAM");
    const deviceToken = generateToken("DEV", 32);

    // Create active camera
    await db.collection("cameras").doc(cameraId).set({
      id: cameraId,
      name: cameraName,
      siteId,
      subadminId,
      deviceId: pendingCamera.deviceId,
      macAddress: pendingCamera.macAddress,
      ipAddress: pendingCamera.ipAddress,
      serialNumber: pendingCamera.hardwareInfo?.serialNumber || "unknown",
      status: "offline",
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      registeredAt: admin.firestore.FieldValue.serverTimestamp(),
      registeredBy: uid,
      deviceToken,
      registrationMethod: "manual-approval",
    });

    // Delete from pending
    await pendingCameraDoc.ref.delete();

    // Add camera to site
    await db.collection("sites").doc(siteId).update({
      assignedCameras: admin.firestore.FieldValue.arrayUnion(cameraId),
    });

    functions.logger.info(`Camera approved: ${cameraId} by ${uid}`);

    return {
      success: true,
      cameraId,
      deviceToken,
      message: "Camera approved successfully",
    };
  } catch (error: any) {
    functions.logger.error("Error approving camera:", error);
    throw error;
  }
});

// ============================================================================
// PROVISIONING SYSTEM
// ============================================================================

/**
 * Generate provisioning token (superadmin only)
 */
export const generateProvisioningToken = functions.https.onCall(
  async (data, context) => {
    try {
      const uid = verifySuperAdmin(context);
      const { cameraName, siteId, expiryDays = 7 } = data;

      if (!cameraName || !siteId) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Camera name and site ID are required"
        );
      }

      // Verify site exists and get subadminId
      const siteDoc = await db.collection("sites").doc(siteId).get();
      if (!siteDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Site not found");
      }

      const site = siteDoc.data()!;
      const token = generateToken("PT", 16);
      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + expiryDays);

      // Create token document
      await db.collection("provisioningTokens").doc(token).set({
        token,
        cameraName,
        siteId,
        subadminId: site.subadminId,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: uid,
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
        usedAt: null,
        assignedCameraId: null,
      });

      functions.logger.info(`Provisioning token generated: ${token} by ${uid}`);

      return {
        success: true,
        token,
        expiresAt: expiresAt.toISOString(),
        message: "Token generated successfully",
      };
    } catch (error: any) {
      functions.logger.error("Error generating provisioning token:", error);
      throw error;
    }
  }
);

/**
 * Get token info (called by RPi before activation)
 */
export const getProvisioningTokenInfo = functions.https.onRequest(
  async (req, res) => {
    // Enable CORS
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      const token = (req.query.token || req.body.token) as string;

      if (!token) {
        res.status(400).json({ success: false, message: "Token is required" });
        return;
      }

      const tokenDoc = await db.collection("provisioningTokens").doc(token).get();

      if (!tokenDoc.exists) {
        res.status(404).json({ success: false, message: "Invalid or expired token" });
        return;
      }

      const tokenData = tokenDoc.data()!;
      
      // Get site name
      const siteDoc = await db.collection("sites").doc(tokenData.siteId).get();
      const siteName = siteDoc.exists ? siteDoc.data()?.name : "Unknown Site";

      res.status(200).json({
        success: true,
        cameraName: tokenData.cameraName,
        siteName: siteName,
        status: tokenData.status,
        expiresAt: tokenData.expiresAt.toDate().toISOString()
      });
    } catch (error: any) {
      functions.logger.error("Error fetching token info:", error);
      res.status(500).json({ success: false, message: error.message });
    }
  }
);

/**
 * Provision camera using token (called by RPi)
 */
export const provisionCamera = functions.https.onRequest(
  async (req, res) => {
    try {
      // Only allow POST
      if (req.method !== "POST") {
        res.status(405).json({ error: "Method not allowed" });
        return;
      }

      const { provisioningToken, deviceInfo } = req.body;

      // Validate input
      if (!provisioningToken || !deviceInfo) {
        res.status(400).json({
          success: false,
          message: "Provisioning token and device info are required",
        });
        return;
      }

      // More lenient token format validation
      if (!provisioningToken.startsWith('PT_')) {
        res.status(400).json({
          success: false,
          message: "Invalid token format"
        });
        return;
      }

      const { macAddress, serialNumber, hostname } = deviceInfo;

      if (!macAddress || !hostname) {
        res.status(400).json({
          success: false,
          message: "MAC address and hostname are required",
        });
        return;
      }

      // Get token document
      const tokenDoc = await db
        .collection("provisioningTokens")
        .doc(provisioningToken)
        .get();

      if (!tokenDoc.exists) {
        res.status(404).json({
          success: false,
          message: "Invalid provisioning token",
        });
        return;
      }

      const tokenData = tokenDoc.data()!;

      // Validate token status
      if (tokenData.status !== "pending") {
        res.status(400).json({
          success: false,
          message: `Token has already been ${tokenData.status}`,
        });
        return;
      }

      // Check expiry
      const now = admin.firestore.Timestamp.now();
      if (tokenData.expiresAt.toMillis() < now.toMillis()) {
        await tokenDoc.ref.update({ status: "expired" });
        res.status(400).json({
          success: false,
          message: "Token has expired",
        });
        return;
      }

      // Generate camera credentials
      const cameraId = generateId("CAM");
      const deviceToken = generateToken("DEV", 32);

      // Create camera document
      await db.collection("cameras").doc(cameraId).set({
        id: cameraId,
        name: tokenData.cameraName,
        siteId: tokenData.siteId,
        subadminId: tokenData.subadminId,
        deviceId: hostname,
        macAddress,
        serialNumber: serialNumber || "unknown",
        status: "online",
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
        registeredAt: admin.firestore.FieldValue.serverTimestamp(),
        registeredBy: "provisioning-token",
        deviceToken,
        registrationMethod: "token-provisioning",
        provisioningToken,
      });

      // Update token status
      await tokenDoc.ref.update({
        status: "used",
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        assignedCameraId: cameraId,
      });

      // Add camera to site
      await db.collection("sites").doc(tokenData.siteId).update({
        assignedCameras: admin.firestore.FieldValue.arrayUnion(cameraId),
      });

      // Prepare configuration for camera (matches camera_agent.py expectations)
      const config = {
        cameraId,
        cameraName: tokenData.cameraName,
        siteId: tokenData.siteId,
        subadminId: tokenData.subadminId,
        deviceId: hostname,
        macAddress,
        serialNumber,
        deviceToken,
        // Use siteId as orgId (can be refined later with proper org hierarchy)
        orgId: tokenData.siteId,
        firebaseConfig: {
          apiKey: "AIzaSyAKCOYmCpOD2aGxDXHul50MPLK1GSrZBr8",
          projectId: "aiodcouter04",
        },
        transmissionConfig: {
          aggregationInterval: 300, // 5 minutes (matches camera_agent.py)
          batchSize: 10,
          maxRetries: 3,
        },
        detectionConfig: {
          detectionZones: [], // Matches camera_agent.py (was 'zones')
          objectClasses: ["person", "vehicle", "forklift"],
          confidenceThreshold: 0.8,
          modelPath: "/opt/camera-agent/model.tflite", // Default model path on RPi
        },
        serviceAccountPath: "/opt/camera-agent/service-account.json", // Expected location on RPi
      };

      functions.logger.info(`Camera provisioned: ${cameraId} via token ${provisioningToken}`);

      res.status(200).json({
        success: true,
        cameraId,
        config,
        message: "Camera provisioned successfully",
      });
    } catch (error: any) {
      functions.logger.error("Error provisioning camera:", error);
      res.status(500).json({
        success: false,
        message: "Internal server error",
        error: error.message,
      });
    }
  }
);

// ============================================================================
// MAINTENANCE FUNCTIONS
// ============================================================================

/**
 * Update camera status (runs every minute)
 */
export const updateCameraStatus = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {
    try {
      const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
      const fiveMinutesAgoTimestamp = admin.firestore.Timestamp.fromDate(fiveMinutesAgo);

      // Get cameras that haven't been seen in 5 minutes and are marked online
      const camerasSnapshot = await db
        .collection("cameras")
        .where("status", "==", "online")
        .where("lastSeen", "<", fiveMinutesAgoTimestamp)
        .get();

      const batch = db.batch();
      camerasSnapshot.docs.forEach((doc) => {
        batch.update(doc.ref, { status: "offline" });
      });

      await batch.commit();

      if (!camerasSnapshot.empty) {
        functions.logger.info(
          `Marked ${camerasSnapshot.size} cameras as offline`
        );
      }

      return null;
    } catch (error: any) {
      functions.logger.error("Error updating camera status:", error);
      return null;
    }
  });

// ============================================================================
// CAMERA DETECTION CONTROL FUNCTIONS
// ============================================================================

/**
 * Start detection on a camera (proxies to RPi API)
 */
export const startCameraDetection = functions.https.onCall(
  async (data, context) => {
    try {
      verifyAuth(context);
      const { cameraId, raspberryPiIp } = data;

      if (!cameraId || !raspberryPiIp) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "cameraId and raspberryPiIp are required"
        );
      }

      // Verify user has access to this camera
      const cameraDoc = await db.collection("cameras").doc(cameraId).get();
      if (!cameraDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Camera not found");
      }

      const cameraData = cameraDoc.data();
      const role = context.auth?.token.role;

      // Check permissions
      if (role === "viewer" || 
          (role === "subadmin" && cameraData?.subadminId !== context.auth?.uid)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You don't have permission to control this camera"
        );
      }

      // Call RPi API
      try {
        const response = await axios.post(
          `http://${raspberryPiIp}:5000/api/detection/start`,
          {
            camera_id: cameraId,
            backend_url: `https://${functions.config().project.region || 'us-central1'}-${functions.config().project.id}.cloudfunctions.net`,
            report_interval: 5
          },
          { timeout: 10000 }
        );

        return {
          success: true,
          data: response.data
        };
      } catch (rpiError: any) {
        functions.logger.error("RPi API error:", rpiError);
        throw new functions.https.HttpsError(
          "internal",
          `Failed to start detection: ${rpiError.message}`
        );
      }
    } catch (error: any) {
      functions.logger.error("Error starting detection:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Failed to start detection"
      );
    }
  }
);

/**
 * Stop detection on a camera (proxies to RPi API)
 */
export const stopCameraDetection = functions.https.onCall(
  async (data, context) => {
    try {
      verifyAuth(context);
      const { cameraId, raspberryPiIp } = data;

      if (!cameraId || !raspberryPiIp) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "cameraId and raspberryPiIp are required"
        );
      }

      // Verify user has access to this camera
      const cameraDoc = await db.collection("cameras").doc(cameraId).get();
      if (!cameraDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Camera not found");
      }

      const cameraData = cameraDoc.data();
      const role = context.auth?.token.role;

      // Check permissions
      if (role === "viewer" || 
          (role === "subadmin" && cameraData?.subadminId !== context.auth?.uid)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "You don't have permission to control this camera"
        );
      }

      // Call RPi API
      try {
        const response = await axios.post(
          `http://${raspberryPiIp}:5000/api/detection/stop`,
          {},
          { timeout: 10000 }
        );

        return {
          success: true,
          data: response.data
        };
      } catch (rpiError: any) {
        functions.logger.error("RPi API error:", rpiError);
        throw new functions.https.HttpsError(
          "internal",
          `Failed to stop detection: ${rpiError.message}`
        );
      }
    } catch (error: any) {
      functions.logger.error("Error stopping detection:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Failed to stop detection"
      );
    }
  }
);

/**
 * Get detection status from RPi
 */
export const getCameraDetectionStatus = functions.https.onCall(
  async (data, context) => {
    try {
      verifyAuth(context);
      const { cameraId, raspberryPiIp } = data;

      if (!cameraId || !raspberryPiIp) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "cameraId and raspberryPiIp are required"
        );
      }

      // Verify user has access to this camera
      const cameraDoc = await db.collection("cameras").doc(cameraId).get();
      if (!cameraDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Camera not found");
      }

      // Call RPi API
      try {
        const response = await axios.get(
          `http://${raspberryPiIp}:5000/api/detection/status`,
          { timeout: 5000 }
        );

        return {
          success: true,
          data: response.data
        };
      } catch (rpiError: any) {
        functions.logger.error("RPi API error:", rpiError);
        throw new functions.https.HttpsError(
          "internal",
          `Failed to get status: ${rpiError.message}`
        );
      }
    } catch (error: any) {
      functions.logger.error("Error getting status:", error);
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }
      throw new functions.https.HttpsError(
        "internal",
        error.message || "Failed to get status"
      );
    }
  }
);

/**
 * Receive detection counts from RPi (HTTP endpoint)
 */
export const receiveDetectionCounts = functions.https.onRequest(
  async (req, res) => {
    try {
      if (req.method !== "POST") {
        return res.status(405).json({ success: false, error: "Method not allowed" });
      }

      const {
        camera_id,
        timestamp,
        counts,
        total_objects,
        frames_processed,
        fps,
        runtime_seconds
      } = req.body;

      if (!camera_id) {
        return res.status(400).json({ success: false, error: "camera_id required" });
      }

      functions.logger.info(`Received counts from camera ${camera_id}:`, counts);

      // You can save to Firestore or process here
      // For now, we'll just log it
      // The counts are already being sent to Firebase by the RPi agent

      res.json({ success: true, received: true });
    } catch (error: any) {
      functions.logger.error("Error receiving counts:", error);
      res.status(500).json({ success: false, error: error.message });
    }
  }
);
