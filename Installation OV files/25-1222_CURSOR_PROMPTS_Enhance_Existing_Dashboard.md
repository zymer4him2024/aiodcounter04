# CURSOR PROMPTS TO ENHANCE YOUR EXISTING DASHBOARD

---

## PROMPT 1: ADD PROVISIONING TOKEN SYSTEM

```
I have an existing Firebase dashboard for camera management. I want to ADD a provisioning token system alongside my current camera approval workflow.

CURRENT SYSTEM:
- Cameras self-register to pending_cameras collection
- Super Admin approves cameras manually
- Collections: pending_cameras, sites, subadmins

NEW FEATURE TO ADD:
Add a "Provisioning" tab with token management:

1. NEW TAB: "Provisioning Tokens"
   - List all provisioning tokens
   - Status badges (pending, used, revoked, expired)
   - Generate new token button
   - Revoke token button

2. GENERATE TOKEN DIALOG:
   - Input: Camera name, Site selection
   - Click "Generate Token"
   - Display: 
     * Token string (PT_XXXXXXXXXXXX)
     * QR code (using qrcode.react library)
     * Expiry date (7 days default)
   - Download QR code button
   - Print QR sticker button

3. FIRESTORE COLLECTION:
provisioningTokens/{token}
  - token: string
  - cameraName: string
  - siteId: string
  - status: 'pending' | 'used' | 'revoked' | 'expired'
  - createdAt: Timestamp
  - createdBy: string (userId)
  - expiresAt: Timestamp
  - usedAt: Timestamp | null
  - assignedCameraId: string | null

4. CLOUD FUNCTION (add to existing functions):
exports.generateProvisioningToken = functions.https.onCall(async (data, context) => {
  // Verify super admin
  // Generate crypto-secure token
  // Create Firestore doc
  // Return token and QR data
});

5. UI REQUIREMENTS:
   - Use same styling as existing tabs
   - Material icons for consistency
   - Same modal pattern as current modals
   - Responsive grid layout for token cards

Generate the React component for the Provisioning tab that integrates with my existing Dashboard.js.
```

---

## PROMPT 2: ADD REAL-TIME COUNT DISPLAY

```
Add real-time count display to my existing camera dashboard.

REQUIREMENTS:

1. NEW TAB: "Analytics"
   - Real-time count cards (today's total)
   - Last 24 hours line chart
   - Breakdown by object type
   - Filter by site/camera

2. FIRESTORE STRUCTURE:
cameras/{cameraId}/counts/{timestamp}
  - timestamp: Timestamp
  - counts: {
      person: { in: 10, out: 8, total: 18 },
      vehicle: { in: 5, out: 5, total: 10 }
    }

3. REAL-TIME UPDATES:
   - Use Firestore onSnapshot
   - Update charts live
   - Show "Live" indicator

4. CHARTS:
   - Use recharts library
   - Line chart for trend
   - Bar chart for hourly breakdown
   - Pie chart for object types

5. UI:
   - Match existing dashboard style
   - Responsive layout
   - Loading states
   - Empty states

Generate the Analytics tab component with real-time Firestore integration.
```

---

## PROMPT 3: ADD DETECTION ZONE CONFIGURATION

```
Add detection zone configuration UI to camera detail view.

REQUIREMENTS:

1. CAMERA DETAIL PAGE:
   - Click on camera card → open detail page
   - Show camera info (name, site, status, MAC, IP)
   - "Configure Zones" button

2. ZONE CONFIGURATION DIALOG:
   - Upload reference image or use camera snapshot
   - Draw polygons on canvas (using fabric.js or konva)
   - Name each zone
   - Set object types for each zone
   - Set confidence threshold (0-1 slider)
   - Save configuration

3. FIRESTORE UPDATE:
cameras/{cameraId}
  - detectionConfig: {
      zones: [
        { 
          id: 'zone1',
          name: 'Entry Area',
          points: [[x1,y1], [x2,y2], ...],
          objectTypes: ['person', 'vehicle'],
          confidenceThreshold: 0.8
        }
      ]
    }

4. UI:
   - Canvas for drawing (HTML5 Canvas or SVG)
   - Color-coded zones
   - Add/remove zone buttons
   - Preview overlay

Generate the zone configuration component that integrates with existing camera management.
```

---

## PROMPT 4: ADD ALERT SYSTEM

```
Add alert system for monitoring camera counts.

REQUIREMENTS:

1. NEW TAB: "Alerts"
   - Active alerts list
   - Alert rules management
   - Alert history

2. CREATE ALERT RULE DIALOG:
   - Select camera/site
   - Condition: "Count exceeds X in Y minutes"
   - Notification channels: Email, SMS, Push
   - Schedule: Active hours (e.g., 9AM-5PM Mon-Fri)
   - Cooldown period: 30 minutes

3. FIRESTORE COLLECTION:
alertRules/{ruleId}
  - name: string
  - cameraId: string
  - condition: { type: 'threshold', value: 50, period: 300 }
  - notifications: { email: true, sms: false }
  - schedule: { start: '09:00', end: '17:00', days: [1,2,3,4,5] }
  - active: boolean

alerts/{alertId}
  - ruleId: string
  - triggeredAt: Timestamp
  - count: number
  - acknowledged: boolean

4. CLOUD FUNCTION:
exports.checkAlertRules = functions.pubsub.schedule('every 1 minutes').onRun(async () => {
  // Check recent counts against alert rules
  // Send notifications if triggered
});

5. UI:
   - Alert badge with count
   - Toast notifications
   - Acknowledge button
   - Alert history table

Generate the alert system components and Cloud Function.
```

---

## PROMPT 5: ADD FIRESTORE SECURITY RULES

```
Create comprehensive Firestore security rules for my existing data model.

CURRENT COLLECTIONS:
- pending_cameras
- sites  
- subadmins
- cameras
- counts

USER ROLES (stored in custom claims):
- superadmin: full access
- subadmin: access to assigned sites only

REQUIREMENTS:

1. SUPERADMIN:
   - Read/write all collections
   - Create/delete subadmins
   - Approve cameras

2. SUBADMIN:
   - Read sites where sites.subadminId == request.auth.uid
   - Read cameras where camera.subadminId == request.auth.uid
   - Read counts for their cameras only
   - Cannot create/delete sites or cameras

3. CAMERA DEVICES:
   - Write to their own counts only
   - Update own status/lastSeen

4. VALIDATION:
   - Validate required fields
   - Validate data types
   - Prevent modification of createdAt, createdBy

Generate complete firestore.rules file with helper functions.
```

---

## PROMPT 6: ADD CAMERA STATUS MONITORING

```
Add real-time camera status monitoring (online/offline).

REQUIREMENTS:

1. CAMERA STATUS INDICATOR:
   - Green dot = online (< 5 min since last heartbeat)
   - Red dot = offline (> 5 min)
   - Last seen timestamp

2. FIRESTORE UPDATE:
cameras/{cameraId}
  - status: 'online' | 'offline'
  - lastSeen: Timestamp

3. CLOUD FUNCTION (background):
exports.updateCameraStatus = functions.pubsub.schedule('every 1 minutes').onRun(async () => {
  // Check all cameras
  // If lastSeen > 5 minutes ago, mark offline
});

4. UI UPDATES:
   - Add status indicator to camera cards
   - Add status filter (show online/offline only)
   - Add "Last seen" tooltip

Generate the status monitoring components and Cloud Function.
```

---

## USAGE INSTRUCTIONS

### Step 1: Add Features One by One

```bash
# 1. Open Cursor AI
# 2. Open your existing Dashboard.js
# 3. Use PROMPT 1 to add Provisioning system
# 4. Use PROMPT 2 to add Analytics
# 5. Use PROMPT 3 to add Zone Configuration
# 6. Use PROMPT 4 to add Alerts
# 7. Use PROMPT 5 to add Security Rules
# 8. Use PROMPT 6 to add Status Monitoring
```

### Step 2: Test Each Feature

After each prompt, test the new feature before moving to the next.

### Step 3: Deploy Incrementally

```bash
# Deploy Cloud Functions
firebase deploy --only functions

# Deploy Security Rules
firebase deploy --only firestore:rules

# Deploy Dashboard
npm run build
firebase deploy --only hosting
```

---

## MIGRATION TIMELINE

**Week 1:**
- Add Provisioning Token system (PROMPT 1)
- Test token generation and QR codes

**Week 2:**
- Add Analytics dashboard (PROMPT 2)
- Add Zone Configuration (PROMPT 3)

**Week 3:**
- Add Alert system (PROMPT 4)
- Add Security Rules (PROMPT 5)

**Week 4:**
- Add Status Monitoring (PROMPT 6)
- Testing and refinement

---

## COMPARISON: BEFORE vs AFTER

### BEFORE (Your Current System):
✅ Camera approval workflow
✅ Site management
✅ Subadmin management
❌ No provisioning tokens
❌ No analytics
❌ No alerts
❌ No zone configuration

### AFTER (Enhanced System):
✅ Camera approval workflow (existing)
✅ Site management (existing)
✅ Subadmin management (existing)
✅ Provisioning tokens with QR codes ← NEW
✅ Real-time analytics ← NEW
✅ Alert system ← NEW
✅ Zone configuration ← NEW
✅ Status monitoring ← NEW
✅ Security rules ← NEW

This approach lets you keep your working system and add features incrementally!
