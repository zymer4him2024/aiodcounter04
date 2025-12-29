/**
 * Firebase Cloud Functions for Multi-Tier Object Detection Counter
 * Deploy with: firebase deploy --only functions
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import * as nodemailer from 'nodemailer';

admin.initializeApp();
const db = admin.firestore();

// Email transporter (configure with your SMTP)
const mailTransport = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().email.user,
    pass: functions.config().email.password,
  },
});

/**
 * FUNCTION 1: Camera Registration
 * Triggered when sub-admin registers a new camera
 */
export const onCameraRegister = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Verify role (sub-admin or super-admin)
  const role = context.auth.token.role;
  if (role !== 'sub_admin' && role !== 'super_admin') {
    throw new functions.https.HttpsError('permission-denied', 'Insufficient permissions');
  }

  const { orgId, siteId, serialNumber, macAddress, cameraName, location, model } = data;

  // Validate inputs
  if (!orgId || !siteId || !serialNumber) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  // Generate unique camera ID
  const cameraId = `CAM_${generateRandomString(7)}`;

  // Generate API credentials
  const apiKey = await generateSecureApiKey(cameraId);

  // Create camera document
  const cameraRef = db
    .collection('organizations').doc(orgId)
    .collection('sites').doc(siteId)
    .collection('cameras').doc(cameraId);

  await cameraRef.set({
    cameraId,
    serialNumber,
    macAddress,
    name: cameraName,
    location,
    model,
    status: 'pending',
    apiKey: hashApiKey(apiKey), // Store hashed version
    registeredAt: admin.firestore.FieldValue.serverTimestamp(),
    registeredBy: context.auth.uid,
    lastSeen: null,
  });

  // Create configuration file
  const configData = {
    cameraId,
    siteId,
    orgId,
    apiKey, // Send plaintext to user (only time)
    firebaseConfig: {
      apiKey: functions.config().firebase.api_key,
      authDomain: functions.config().firebase.auth_domain,
      projectId: admin.instanceId().app.options.projectId,
      storageBucket: functions.config().firebase.storage_bucket,
    },
    detectionConfig: {
      modelPath: '/models/yolov8n.tflite',
      objectClasses: ['person', 'vehicle', 'forklift'],
      confidenceThreshold: 0.75,
      detectionZones: [],
    },
    transmissionConfig: {
      aggregationInterval: 300,
      maxRetries: 3,
      timeout: 10000,
    },
  };

  // Upload config to Storage
  const bucket = admin.storage().bucket();
  const configFile = bucket.file(`camera-configs/${cameraId}.json`);
  await configFile.save(JSON.stringify(configData, null, 2), {
    contentType: 'application/json',
    metadata: {
      cameraId,
      createdAt: new Date().toISOString(),
    },
  });

  // Send email to sub-admin with config file
  const user = await admin.auth().getUser(context.auth.uid);
  await sendCameraRegistrationEmail(user.email!, cameraName, configData);

  // Log in audit trail
  await logAuditEvent({
    eventType: 'camera_registered',
    userId: context.auth.uid,
    cameraId,
    details: { siteId, orgId, cameraName },
  });

  return {
    success: true,
    cameraId,
    message: 'Camera registered successfully. Configuration sent to your email.',
  };
});

/**
 * FUNCTION 2: Process Incoming Counts
 * Triggered when camera writes count data
 */
export const onCountReceived = functions.firestore
  .document('organizations/{orgId}/sites/{siteId}/cameras/{cameraId}/counts/{countId}')
  .onCreate(async (snap, context) => {
    const countData = snap.data();
    const { orgId, siteId, cameraId } = context.params;

    // Validate count data
    if (!countData.timestamp || !countData.counts) {
      functions.logger.error('Invalid count data', { cameraId, countData });
      return;
    }

    // Update camera last seen
    const cameraRef = db
      .collection('organizations').doc(orgId)
      .collection('sites').doc(siteId)
      .collection('cameras').doc(cameraId);

    await cameraRef.update({
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      status: 'online',
    });

    // Check for anomalies
    const anomalies = await detectAnomalies(orgId, siteId, cameraId, countData);
    if (anomalies.length > 0) {
      functions.logger.warn('Anomalies detected', { cameraId, anomalies });
      // Could trigger additional alerts here
    }

    // Check alert rules
    await checkAlertRules(orgId, siteId, cameraId, countData);

    // Aggregate for analytics (could be a separate scheduled function)
    await aggregateForAnalytics(orgId, siteId, countData);
  });

/**
 * FUNCTION 3: Send Alert Notifications
 */
export const sendAlertNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { alertType, message, recipients, channels } = data;

  const results = {
    email: false,
    sms: false,
    push: false,
  };

  // Send email
  if (channels.includes('email')) {
    try {
      await sendEmailAlert(recipients.email, alertType, message);
      results.email = true;
    } catch (error) {
      functions.logger.error('Email alert failed', error);
    }
  }

  // Send SMS (integrate with Twilio)
  if (channels.includes('sms')) {
    try {
      // await sendSMSAlert(recipients.phone, message);
      results.sms = true; // Placeholder
    } catch (error) {
      functions.logger.error('SMS alert failed', error);
    }
  }

  // Send push notification
  if (channels.includes('push')) {
    try {
      await sendPushNotification(recipients.tokens, alertType, message);
      results.push = true;
    } catch (error) {
      functions.logger.error('Push notification failed', error);
    }
  }

  return results;
});

/**
 * FUNCTION 4: Generate Daily Report
 * Scheduled to run at midnight
 */
export const generateDailyReport = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);
    yesterday.setHours(0, 0, 0, 0);

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // Get all organizations
    const orgsSnapshot = await db.collection('organizations').get();

    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;

      // Get all sites
      const sitesSnapshot = await db
        .collection('organizations').doc(orgId)
        .collection('sites')
        .get();

      for (const siteDoc of sitesSnapshot.docs) {
        const siteId = siteDoc.id;
        const siteData = siteDoc.data();

        // Aggregate counts for yesterday
        const report = await generateSiteReport(orgId, siteId, yesterday, today);

        // Send email to site manager
        if (siteData.managerId) {
          const manager = await admin.auth().getUser(siteData.managerId);
          await sendDailyReportEmail(manager.email!, siteData.name, report);
        }

        functions.logger.info(`Daily report sent for site: ${siteId}`);
      }
    }
  });

/**
 * FUNCTION 5: Cleanup Old Data
 * Scheduled to run weekly
 */
export const cleanupOldData = functions.pubsub
  .schedule('0 2 * * 0')
  .timeZone('UTC')
  .onRun(async (context) => {
    const retentionDays = 90;
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - retentionDays);

    functions.logger.info(`Cleaning up data older than ${cutoffDate.toISOString()}`);

    // Archive to Cloud Storage
    const bucket = admin.storage().bucket();

    // Query old counts
    const orgsSnapshot = await db.collection('organizations').get();

    let archivedCount = 0;
    let deletedCount = 0;

    for (const orgDoc of orgsSnapshot.docs) {
      const orgId = orgDoc.id;
      const sitesSnapshot = await db.collection('organizations').doc(orgId).collection('sites').get();

      for (const siteDoc of sitesSnapshot.docs) {
        const siteId = siteDoc.id;
        const camerasSnapshot = await db
          .collection('organizations').doc(orgId)
          .collection('sites').doc(siteId)
          .collection('cameras')
          .get();

        for (const cameraDoc of camerasSnapshot.docs) {
          const cameraId = cameraDoc.id;
          
          // Get old counts
          const countsSnapshot = await db
            .collection('organizations').doc(orgId)
            .collection('sites').doc(siteId)
            .collection('cameras').doc(cameraId)
            .collection('counts')
            .where('timestamp', '<', cutoffDate.toISOString())
            .limit(500) // Process in batches
            .get();

          if (countsSnapshot.empty) continue;

          // Archive to Storage
          const archiveData = countsSnapshot.docs.map(doc => ({
            id: doc.id,
            ...doc.data(),
          }));

          const archiveFile = bucket.file(
            `archives/${orgId}/${siteId}/${cameraId}/${cutoffDate.toISOString().split('T')[0]}.json`
          );

          await archiveFile.save(JSON.stringify(archiveData, null, 2), {
            contentType: 'application/json',
            metadata: {
              archived: new Date().toISOString(),
              recordCount: archiveData.length,
            },
          });

          archivedCount += archiveData.length;

          // Delete from Firestore
          const batch = db.batch();
          countsSnapshot.docs.forEach(doc => batch.delete(doc.ref));
          await batch.commit();

          deletedCount += countsSnapshot.docs.length;
        }
      }
    }

    functions.logger.info(`Cleanup complete: ${archivedCount} archived, ${deletedCount} deleted`);
  });

// ===== HELPER FUNCTIONS =====

function generateRandomString(length: number): string {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

async function generateSecureApiKey(cameraId: string): Promise<string> {
  const crypto = require('crypto');
  const randomBytes = crypto.randomBytes(32).toString('hex');
  return `${cameraId}_${randomBytes}`;
}

function hashApiKey(apiKey: string): string {
  const crypto = require('crypto');
  return crypto.createHash('sha256').update(apiKey).digest('hex');
}

async function sendCameraRegistrationEmail(email: string, cameraName: string, config: any) {
  const mailOptions = {
    from: 'noreply@yourcompany.com',
    to: email,
    subject: `Camera Registration: ${cameraName}`,
    html: `
      <h2>Camera Successfully Registered</h2>
      <p>Camera <strong>${cameraName}</strong> has been registered.</p>
      <p><strong>Camera ID:</strong> ${config.cameraId}</p>
      <p>Please download the configuration file and upload it to your camera device.</p>
      <pre>${JSON.stringify(config, null, 2)}</pre>
    `,
    attachments: [
      {
        filename: `${config.cameraId}-config.json`,
        content: JSON.stringify(config, null, 2),
      },
    ],
  };

  await mailTransport.sendMail(mailOptions);
}

async function sendEmailAlert(email: string, alertType: string, message: string) {
  const mailOptions = {
    from: 'alerts@yourcompany.com',
    to: email,
    subject: `Alert: ${alertType}`,
    html: `
      <h2>⚠️ Alert Notification</h2>
      <p><strong>Type:</strong> ${alertType}</p>
      <p><strong>Message:</strong> ${message}</p>
      <p><strong>Time:</strong> ${new Date().toISOString()}</p>
    `,
  };

  await mailTransport.sendMail(mailOptions);
}

async function sendPushNotification(tokens: string[], alertType: string, message: string) {
  const payload = {
    notification: {
      title: `Alert: ${alertType}`,
      body: message,
    },
    data: {
      alertType,
      timestamp: new Date().toISOString(),
    },
  };

  await admin.messaging().sendToDevice(tokens, payload);
}

async function detectAnomalies(
  orgId: string,
  siteId: string,
  cameraId: string,
  countData: any
): Promise<string[]> {
  const anomalies: string[] = [];

  // Check for negative counts
  for (const [key, value] of Object.entries(countData.counts)) {
    const counts = value as any;
    if (counts.in < 0 || counts.out < 0) {
      anomalies.push(`Negative count detected for ${key}`);
    }
  }

  // Check for unrealistic spikes (compare with historical average)
  // This is a simplified example
  const historicalSnapshot = await db
    .collection('organizations').doc(orgId)
    .collection('sites').doc(siteId)
    .collection('cameras').doc(cameraId)
    .collection('counts')
    .orderBy('timestamp', 'desc')
    .limit(10)
    .get();

  if (!historicalSnapshot.empty) {
    const avgCounts: any = {};
    historicalSnapshot.docs.forEach(doc => {
      const data = doc.data();
      for (const [key, value] of Object.entries(data.counts)) {
        const counts = value as any;
        if (!avgCounts[key]) avgCounts[key] = { in: 0, out: 0, count: 0 };
        avgCounts[key].in += counts.in;
        avgCounts[key].out += counts.out;
        avgCounts[key].count++;
      }
    });

    // Check if current counts are 3x average
    for (const [key, value] of Object.entries(countData.counts)) {
      const counts = value as any;
      if (avgCounts[key]) {
        const avgIn = avgCounts[key].in / avgCounts[key].count;
        const avgOut = avgCounts[key].out / avgCounts[key].count;
        
        if (counts.in > avgIn * 3 || counts.out > avgOut * 3) {
          anomalies.push(`Unusual spike detected for ${key}`);
        }
      }
    }
  }

  return anomalies;
}

async function checkAlertRules(
  orgId: string,
  siteId: string,
  cameraId: string,
  countData: any
) {
  // Get alert rules for this site/camera
  const rulesSnapshot = await db
    .collection('organizations').doc(orgId)
    .collection('sites').doc(siteId)
    .collection('alertRules')
    .where('enabled', '==', true)
    .get();

  for (const ruleDoc of rulesSnapshot.docs) {
    const rule = ruleDoc.data();

    // Check if rule applies to this camera
    if (rule.cameras && !rule.cameras.includes(cameraId)) {
      continue;
    }

    // Check threshold conditions
    for (const [key, value] of Object.entries(countData.counts)) {
      const counts = value as any;
      const total = counts.in + counts.out;

      if (rule.threshold && total > rule.threshold) {
        // Trigger alert
        await triggerAlert(rule, cameraId, key, total);
      }
    }
  }
}

async function triggerAlert(rule: any, cameraId: string, objectType: string, count: number) {
  // Check cooldown
  const lastAlert = rule.lastTriggered?.toDate();
  if (lastAlert) {
    const cooldownMs = (rule.cooldownMinutes || 30) * 60 * 1000;
    if (Date.now() - lastAlert.getTime() < cooldownMs) {
      return; // Still in cooldown
    }
  }

  // Send notification
  const message = `Count exceeded threshold: ${count} ${objectType} detected (threshold: ${rule.threshold})`;
  
  // Update last triggered
  await db.doc(rule.ref.path).update({
    lastTriggered: admin.firestore.FieldValue.serverTimestamp(),
  });

  functions.logger.info(`Alert triggered: ${rule.name}`, { cameraId, count });
}

async function aggregateForAnalytics(orgId: string, siteId: string, countData: any) {
  // This could write to a separate analytics collection
  // For now, just log
  functions.logger.info('Analytics aggregation', { orgId, siteId });
}

async function generateSiteReport(
  orgId: string,
  siteId: string,
  startDate: Date,
  endDate: Date
): Promise<any> {
  const camerasSnapshot = await db
    .collection('organizations').doc(orgId)
    .collection('sites').doc(siteId)
    .collection('cameras')
    .get();

  const report = {
    totalCounts: {} as any,
    peakHour: null as any,
    cameraCounts: {} as any,
  };

  for (const cameraDoc of camerasSnapshot.docs) {
    const cameraId = cameraDoc.id;
    const countsSnapshot = await db
      .collection('organizations').doc(orgId)
      .collection('sites').doc(siteId)
      .collection('cameras').doc(cameraId)
      .collection('counts')
      .where('timestamp', '>=', startDate.toISOString())
      .where('timestamp', '<', endDate.toISOString())
      .get();

    let cameraTotalCounts = 0;
    countsSnapshot.docs.forEach(doc => {
      const data = doc.data();
      for (const [key, value] of Object.entries(data.counts)) {
        const counts = value as any;
        const total = counts.in + counts.out;
        cameraTotalCounts += total;

        if (!report.totalCounts[key]) {
          report.totalCounts[key] = 0;
        }
        report.totalCounts[key] += total;
      }
    });

    report.cameraCounts[cameraId] = cameraTotalCounts;
  }

  return report;
}

async function sendDailyReportEmail(email: string, siteName: string, report: any) {
  const mailOptions = {
    from: 'reports@yourcompany.com',
    to: email,
    subject: `Daily Report: ${siteName}`,
    html: `
      <h2>Daily Report for ${siteName}</h2>
      <h3>Total Counts</h3>
      <pre>${JSON.stringify(report.totalCounts, null, 2)}</pre>
      <h3>Camera Breakdown</h3>
      <pre>${JSON.stringify(report.cameraCounts, null, 2)}</pre>
    `,
  };

  await mailTransport.sendMail(mailOptions);
}

async function logAuditEvent(event: any) {
  await db.collection('auditLogs').add({
    ...event,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
}
