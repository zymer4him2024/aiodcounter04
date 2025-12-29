"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.approveCamera = exports.createSite = exports.createSubadmin = exports.createSuperadmin = exports.createSuperadminFromGoogle = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
// Initialize Firebase Admin (only once)
if (!admin.apps.length) {
    admin.initializeApp();
}
/**
 * Create a superadmin account from Google-authenticated user
 * - If no superadmins exist: any authenticated Google user can become the first superadmin
 * - If superadmins exist: ONLY authenticated superadmins can create additional ones
 */
exports.createSuperadminFromGoogle = functions.https.onCall(async (data, context) => {
    const { companyName } = data;
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be signed in with Google');
    }
    if (!companyName || !companyName.trim()) {
        throw new functions.https.HttpsError('invalid-argument', 'Company name is required');
    }
    const db = admin.firestore();
    try {
        // Check if any superadmins exist
        const superadminsSnapshot = await db.collection('superadmins').limit(1).get();
        const hasSuperadmins = !superadminsSnapshot.empty;
        // If superadmins already exist, ONLY superadmins can create more
        if (hasSuperadmins) {
            // Require authentication and superadmin role
            if (!context.auth.token.role || context.auth.token.role !== 'superadmin') {
                throw new functions.https.HttpsError('permission-denied', 'Only superadmins can create additional superadmin accounts');
            }
        }
        const userId = context.auth.uid;
        const userEmail = context.auth.token.email;
        const userName = context.auth.token.name || (userEmail === null || userEmail === void 0 ? void 0 : userEmail.split('@')[0]) || 'User';
        // Check if user is already a superadmin
        const existingSuperadmin = await db.collection('superadmins').doc(userId).get();
        if (existingSuperadmin.exists) {
            // User already exists - just refresh their custom claims and update company name if needed
            console.log('User already registered as superadmin, refreshing claims...');
            // Set custom claim for role (refresh it)
            await admin.auth().setCustomUserClaims(userId, {
                role: 'superadmin'
            });
            // Update Firestore document (merge to preserve existing data, but update company name if provided)
            await db.collection('superadmins').doc(userId).set({
                email: userEmail,
                name: userName,
                companyName: companyName.trim(),
                role: 'superadmin'
            }, { merge: true });
            return {
                success: true,
                superadminId: userId,
                message: 'Superadmin account refreshed successfully',
                alreadyExisted: true
            };
        }
        // Set custom claim for role
        await admin.auth().setCustomUserClaims(userId, {
            role: 'superadmin'
        });
        // Create Firestore document
        await db.collection('superadmins').doc(userId).set({
            email: userEmail,
            name: userName,
            companyName: companyName.trim(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            role: 'superadmin'
        });
        return {
            success: true,
            superadminId: userId,
            message: 'Superadmin created successfully'
        };
    }
    catch (error) {
        console.error('Error creating superadmin from Google:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', error.message || 'Failed to create superadmin');
    }
});
/**
 * Create a superadmin account (legacy email/password method)
 * - If no superadmins exist: anyone can create the first one (initial setup)
 * - If superadmins exist: ONLY authenticated superadmins can create additional ones
 */
exports.createSuperadmin = functions.https.onCall(async (data, context) => {
    const { email, password, name, companyName } = data;
    if (!email || !password || !name || !companyName) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: email, password, name, companyName');
    }
    const db = admin.firestore();
    try {
        // Check if any superadmins exist
        const superadminsSnapshot = await db.collection('superadmins').limit(1).get();
        const hasSuperadmins = !superadminsSnapshot.empty;
        // If superadmins already exist, ONLY superadmins can create more
        if (hasSuperadmins) {
            // Require authentication and superadmin role
            if (!context.auth || !context.auth.token.role || context.auth.token.role !== 'superadmin') {
                throw new functions.https.HttpsError('permission-denied', 'Only superadmins can create additional superadmin accounts');
            }
        }
        // Check if user already exists
        let userRecord;
        try {
            userRecord = await admin.auth().getUserByEmail(email);
            // User exists, check if already a superadmin
            const existingSuperadmin = await db.collection('superadmins').doc(userRecord.uid).get();
            if (existingSuperadmin.exists) {
                throw new functions.https.HttpsError('already-exists', 'This email is already registered as a superadmin');
            }
            // User exists but not superadmin - update them
            await admin.auth().setCustomUserClaims(userRecord.uid, {
                role: 'superadmin'
            });
        }
        catch (error) {
            if (error.code === 'auth/user-not-found') {
                // Create new user
                userRecord = await admin.auth().createUser({
                    email,
                    password,
                    displayName: name,
                });
                await admin.auth().setCustomUserClaims(userRecord.uid, {
                    role: 'superadmin'
                });
            }
            else if (error instanceof functions.https.HttpsError) {
                throw error;
            }
            else {
                throw new functions.https.HttpsError('internal', error.message || 'Failed to create user');
            }
        }
        // Create or update Firestore document
        await db.collection('superadmins').doc(userRecord.uid).set({
            email,
            name,
            companyName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            role: 'superadmin'
        }, { merge: true });
        return {
            success: true,
            superadminId: userRecord.uid,
            message: 'Superadmin created successfully'
        };
    }
    catch (error) {
        console.error('Error creating superadmin:', error);
        if (error instanceof functions.https.HttpsError) {
            throw error;
        }
        throw new functions.https.HttpsError('internal', error.message || 'Failed to create superadmin');
    }
});
/**
 * Create a new subadmin account
 * Only callable by superadmins
 */
exports.createSubadmin = functions.https.onCall(async (data, context) => {
    // Verify caller is superadmin
    if (!context.auth || !context.auth.token.role || context.auth.token.role !== 'superadmin') {
        throw new functions.https.HttpsError('permission-denied', 'Only superadmins can create subadmin accounts');
    }
    const { email, password, name, companyName } = data;
    if (!email || !password || !name || !companyName) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields: email, password, name, companyName');
    }
    try {
        // Create Firebase Auth user
        const userRecord = await admin.auth().createUser({
            email,
            password,
            displayName: name,
        });
        // Set custom claim for role
        await admin.auth().setCustomUserClaims(userRecord.uid, {
            role: 'subadmin'
        });
        // Create Firestore document
        const db = admin.firestore();
        await db.collection('subadmins').doc(userRecord.uid).set({
            email,
            name,
            companyName,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            createdBy: context.auth.uid,
            role: 'subadmin',
            assignedSites: []
        });
        return {
            success: true,
            subadminId: userRecord.uid,
            message: 'Subadmin created successfully'
        };
    }
    catch (error) {
        console.error('Error creating subadmin:', error);
        throw new functions.https.HttpsError('internal', error.message || 'Failed to create subadmin');
    }
});
/**
 * Create a new site
 * Only callable by superadmins
 */
exports.createSite = functions.https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.role !== 'superadmin') {
        throw new functions.https.HttpsError('permission-denied', 'Only superadmins can create sites');
    }
    const { name, location, subadminId } = data;
    if (!name || !location || !subadminId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    const db = admin.firestore();
    try {
        // Verify subadmin exists
        const subadminDoc = await db.collection('subadmins').doc(subadminId).get();
        if (!subadminDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Subadmin not found');
        }
        // Create site
        const siteRef = db.collection('sites').doc();
        await siteRef.set({
            name,
            location,
            subadminId,
            createdBy: context.auth.uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            status: 'active',
            assignedCameras: []
        });
        // Update subadmin's assignedSites
        await db.collection('subadmins').doc(subadminId).update({
            assignedSites: admin.firestore.FieldValue.arrayUnion(siteRef.id)
        });
        return {
            success: true,
            siteId: siteRef.id,
            message: 'Site created successfully'
        };
    }
    catch (error) {
        console.error('Error creating site:', error);
        throw new functions.https.HttpsError('internal', error.message || 'Failed to create site');
    }
});
/**
 * Approve a pending camera and activate it
 * Only callable by superadmins
 */
exports.approveCamera = functions.https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.role !== 'superadmin') {
        throw new functions.https.HttpsError('permission-denied', 'Only superadmins can approve cameras');
    }
    const { deviceId, cameraName, siteId, subadminId } = data;
    if (!deviceId || !cameraName || !siteId || !subadminId) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }
    const db = admin.firestore();
    try {
        // Get pending camera data
        const pendingRef = db.collection('pending_cameras').doc(deviceId);
        const pendingDoc = await pendingRef.get();
        if (!pendingDoc.exists) {
            throw new functions.https.HttpsError('not-found', 'Pending camera not found');
        }
        const pendingData = pendingDoc.data();
        // Generate secure device token
        const deviceToken = crypto.randomBytes(32).toString('hex');
        // Create camera document
        const cameraRef = db.collection('cameras').doc();
        const cameraData = {
            name: cameraName,
            deviceToken: deviceToken,
            deviceId: deviceId,
            siteId: siteId,
            subadminId: subadminId,
            status: 'active',
            lastSeen: admin.firestore.FieldValue.serverTimestamp(),
            ipAddress: pendingData.ipAddress,
            macAddress: pendingData.macAddress,
            modelType: pendingData.hardwareInfo.model,
            createdBy: context.auth.uid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedBy: context.auth.uid,
            approvedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        // Batch write: create camera, update site, delete pending
        const batch = db.batch();
        batch.set(cameraRef, cameraData);
        batch.update(db.collection('sites').doc(siteId), {
            assignedCameras: admin.firestore.FieldValue.arrayUnion(cameraRef.id)
        });
        batch.delete(pendingRef);
        await batch.commit();
        // Log audit trail
        await db.collection('audit_logs').add({
            action: 'camera_approved',
            actor: context.auth.uid,
            actorRole: 'superadmin',
            target: cameraRef.id,
            details: {
                deviceId,
                cameraName,
                siteId,
                subadminId
            },
            timestamp: admin.firestore.FieldValue.serverTimestamp()
        });
        return {
            success: true,
            cameraId: cameraRef.id,
            message: 'Camera approved and activated'
        };
    }
    catch (error) {
        console.error('Error approving camera:', error);
        throw new functions.https.HttpsError('internal', error.message || 'Failed to approve camera');
    }
});
//# sourceMappingURL=admin.js.map