# COMPLETE IMPLEMENTATION GUIDE
## Firebase Backend + Enhanced Dashboard

---

## CURRENT STATE ANALYSIS

✅ **What You Have:**
- React dashboard (CRA)
- Firebase SDK v12.7.0
- Two hosting targets (superadmin/subadmin)
- Basic Firestore rules
- No Cloud Functions yet

❌ **What's Missing:**
- Cloud Functions (backend logic)
- Real-time count data structure
- Analytics features
- Alert system
- Provisioning system
- Enhanced security rules

---

## STEP 1: INSTALL DEPENDENCIES

### Dashboard (Web App)

```bash
cd web-dashboard

npm install recharts qrcode.react date-fns

# Optional but recommended:
npm install react-router-dom  # For camera detail pages
npm install @headlessui/react  # For better modals
```

### Cloud Functions (New)

```bash
# Initialize Firebase Functions
firebase init functions

# Select:
# - TypeScript (recommended) or JavaScript
# - ESLint: Yes
# - Install dependencies: Yes

# Then install additional packages:
cd functions
npm install crypto uuid sendgrid twilio
```

---

## STEP 2: FIREBASE FUNCTIONS SETUP

Create these files in `/functions` directory:

### functions/package.json

```json
{
  "name": "functions",
  "scripts": {
    "lint": "eslint --ext .js,.ts .",
    "build": "tsc",
    "build:watch": "tsc --watch",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^4.5.0",
    "crypto": "^1.0.1",
    "uuid": "^9.0.0"
  },
  "devDependencies": {
    "@typescript-eslint/eslint-plugin": "^5.12.0",
    "@typescript-eslint/parser": "^5.12.0",
    "eslint": "^8.9.0",
    "eslint-config-google": "^0.14.0",
    "eslint-plugin-import": "^2.25.4",
    "typescript": "^4.9.0",
    "firebase-functions-test": "^3.1.0"
  },
  "private": true
}
```

---

## STEP 3: UPDATE FIRESTORE RULES

Replace your `firestore.rules` with enhanced version:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ===== HELPER FUNCTIONS =====
    
    function isAuthenticated() {
      return request.auth != null;
    }
    
    function isSuperadmin() {
      return isAuthenticated() && 
             request.auth.token.role == 'superadmin';
    }
    
    function isSubadmin() {
      return isAuthenticated() && 
             request.auth.token.role == 'subadmin';
    }
    
    function isViewer() {
      return isAuthenticated() && 
             request.auth.token.role == 'viewer';
    }
    
    function isValidCameraToken() {
      return isAuthenticated() && 
             request.auth.token.deviceToken != null;
    }
    
    function canViewSite(siteId) {
      return isSuperadmin() || 
             (isSubadmin() && siteId in get(/databases/$(database)/documents/subadmins/$(request.auth.uid)).data.assignedSites);
    }
    
    function canViewCamera(cameraId) {
      return isSuperadmin() ||
             (isViewer() && cameraId in request.auth.token.assignedCameras);
    }
    
    // ===== SUPERADMINS =====
    
    match /superadmins/{adminId} {
      allow read: if true; // For setup detection
      allow write: if false; // Only through Admin SDK
    }
    
    match /superadmins {
      allow list: if true; // For setup detection
    }
    
    // ===== SUBADMINS =====
    
    match /subadmins/{subadminId} {
      allow read: if isSuperadmin() || (isSubadmin() && request.auth.uid == subadminId);
      allow write: if isSuperadmin();
    }
    
    match /subadmins {
      allow list: if isSuperadmin();
    }
    
    // ===== VIEWERS (NEW) =====
    
    match /viewers/{viewerId} {
      allow read: if isSuperadmin() || (isViewer() && request.auth.uid == viewerId);
      allow write: if isSuperadmin();
    }
    
    match /viewers {
      allow list: if isSuperadmin();
    }
    
    // ===== SITES =====
    
    match /sites/{siteId} {
      allow read: if isSuperadmin() || 
                     (isSubadmin() && resource.data.subadminId == request.auth.uid) ||
                     isViewer(); // Viewers can read sites (for display)
      allow write: if isSuperadmin();
    }
    
    match /sites {
      allow list: if isSuperadmin() || isSubadmin() || isViewer();
    }
    
    // ===== PENDING CAMERAS =====
    
    match /pending_cameras/{deviceId} {
      allow create: if request.resource.data.deviceId == deviceId &&
                       request.resource.data.status == 'pending';
      allow update: if request.resource.data.deviceId == resource.data.deviceId &&
                       request.resource.data.diff(resource.data).affectedKeys().hasOnly(['lastSeen']);
      allow read, delete: if isSuperadmin();
    }
    
    match /pending_cameras {
      allow list: if isSuperadmin();
    }
    
    // ===== ACTIVE CAMERAS =====
    
    match /cameras/{cameraId} {
      allow read: if isSuperadmin() || 
                     (isSubadmin() && resource.data.subadminId == request.auth.uid) ||
                     canViewCamera(cameraId);
      allow write: if isSuperadmin();
      
      // Allow camera devices to update status
      allow update: if isValidCameraToken() && 
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['status', 'lastSeen', 'ipAddress']);
      
      // ===== COUNTS SUBCOLLECTION =====
      match /counts/{timestamp} {
        allow read: if isSuperadmin() || 
                       (isSubadmin() && get(/databases/$(database)/documents/cameras/$(cameraId)).data.subadminId == request.auth.uid) ||
                       canViewCamera(cameraId);
        allow create: if isValidCameraToken();
        allow update, delete: if false; // Immutable
      }
    }
    
    match /cameras {
      allow list: if isSuperadmin() || isSubadmin() || isViewer();
    }
    
    // ===== PROVISIONING TOKENS (NEW) =====
    
    match /provisioningTokens/{token} {
      allow read, write: if isSuperadmin();
      // Allow RPi to read for validation during activation
      allow read: if isAuthenticated();
    }
    
    match /provisioningTokens {
      allow list: if isSuperadmin();
    }
    
    // ===== ALERT RULES (NEW) =====
    
    match /alertRules/{ruleId} {
      allow read: if isSuperadmin() || 
                     (isSubadmin() && resource.data.siteId in get(/databases/$(database)/documents/subadmins/$(request.auth.uid)).data.assignedSites);
      allow write: if isSuperadmin();
    }
    
    match /alertRules {
      allow list: if isSuperadmin() || isSubadmin();
    }
    
    // ===== ALERTS (NEW) =====
    
    match /alerts/{alertId} {
      allow read: if isSuperadmin() || 
                     (isSubadmin() && resource.data.siteId in get(/databases/$(database)/documents/subadmins/$(request.auth.uid)).data.assignedSites) ||
                     (isViewer() && canViewCamera(resource.data.cameraId));
      allow create: if false; // Only Cloud Functions
      allow update: if isSuperadmin() || isSubadmin(); // For acknowledging
      allow delete: if isSuperadmin();
    }
    
    match /alerts {
      allow list: if isSuperadmin() || isSubadmin() || isViewer();
    }
  }
}
```

---

## STEP 4: UPDATE PACKAGE.JSON (Dashboard)

Add new dependencies to `web-dashboard/package.json`:

```json
{
  "name": "web-dashboard",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@testing-library/dom": "^10.4.1",
    "@testing-library/jest-dom": "^6.9.1",
    "@testing-library/react": "^16.3.1",
    "@testing-library/user-event": "^13.5.0",
    "firebase": "^12.7.0",
    "lucide-react": "^0.562.0",
    "react": "^19.2.3",
    "react-dom": "^19.2.3",
    "react-scripts": "5.0.1",
    "web-vitals": "^2.1.4",
    
    "recharts": "^2.13.0",
    "qrcode.react": "^4.1.0",
    "date-fns": "^4.1.0",
    "react-router-dom": "^6.28.0"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject",
    "deploy:subadmin": "npm run build && firebase deploy --only hosting:subadmin",
    "deploy:superadmin": "npm run build && firebase deploy --only hosting:superadmin",
    "deploy:all": "npm run build && firebase deploy --only hosting",
    "deploy:functions": "cd ../functions && npm run deploy",
    "deploy:rules": "firebase deploy --only firestore:rules",
    "deploy:backend": "npm run deploy:functions && npm run deploy:rules"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
```

---

## STEP 5: CURSOR PROMPTS (READY TO USE)

Now you're ready for the Cursor prompts. Use them in this exact order:

### PROMPT 1: Cloud Functions Foundation

```
Create Firebase Cloud Functions for my camera management system.

PROJECT INFO:
- Firebase project: aiodcouter04
- Node.js: 18
- TypeScript
- Firebase Admin SDK v12
- Firebase Functions v4.5

EXISTING COLLECTIONS:
- superadmins/{uid}
- subadmins/{uid}
- sites/{siteId}
- pending_cameras/{deviceId}

NEW COLLECTIONS TO CREATE:
- cameras/{cameraId} with subcollection counts/{timestamp}
- viewers/{uid}
- provisioningTokens/{token}
- alertRules/{ruleId}
- alerts/{alertId}

FUNCTIONS TO CREATE:

1. createSuperadmin (HTTPS callable)
   - Create first superadmin account
   - Set custom claims: { role: 'superadmin' }
   - Create Firestore doc in superadmins collection

2. createSubadmin (HTTPS callable)
   - Superadmin only
   - Create subadmin account
   - Set custom claims: { role: 'subadmin', assignedSites: [] }
   - Create Firestore doc in subadmins collection

3. createViewer (HTTPS callable) - NEW
   - Superadmin only
   - Create viewer account
   - Set custom claims: { role: 'viewer', assignedCameras: [] }
   - Create Firestore doc in viewers collection

4. approveCamera (HTTPS callable)
   - Superadmin only
   - Move from pending_cameras to cameras collection
   - Generate camera credentials
   - Set camera custom claims for device auth

5. generateProvisioningToken (HTTPS callable) - NEW
   - Superadmin only
   - Generate crypto-random token (PT_XXXXXXXXXXXX)
   - Create Firestore doc with expiry (7 days)
   - Return token for QR code generation

6. provisionCamera (HTTPS request) - NEW
   - Called by RPi during activation
   - Validate provisioning token
   - Create camera in cameras collection
   - Mark token as used
   - Return camera credentials

7. updateCameraStatus (scheduled, every 1 minute) - NEW
   - Check all cameras lastSeen
   - Mark offline if > 5 minutes
   - Update status field

REQUIREMENTS:
- Use TypeScript
- Export all functions from index.ts
- Add error handling
- Add logging
- Validate inputs
- Use Admin SDK for Firestore and Auth
- Comment the code

Generate complete functions/src/index.ts file.
```

---

### PROMPT 2: Enhanced App.js with Viewer Role

```
Enhance my existing App.js to support viewer role.

CURRENT APP.JS:
[Paste your App.js file]

CHANGES NEEDED:

1. Add VIEWER role support:
```javascript
const ROLES = {
  SUPERADMIN: 'superadmin',
  SUBADMIN: 'subadmin',
  VIEWER: 'viewer'  // NEW
};
```

2. Update site access validation:
   - Superadmin site: Only superadmin
   - Subadmin site: Subadmin AND Viewer

3. Update role checking logic:
```javascript
if (HOSTING_SITE === 'subadmin' && 
    ![ROLES.SUBADMIN, ROLES.VIEWER].includes(role)) {
  // Access denied
}
```

4. Keep ALL existing functionality:
   - Multi-site detection
   - Setup check
   - Token refresh
   - Error handling

5. Add viewer-specific access message if needed

Generate the enhanced App.js file with viewer role support.
```

---

### PROMPT 3: Active Cameras Tab

```
Add "Active Cameras" tab to my existing Dashboard.js.

CURRENT DASHBOARD.JS:
[Paste your Dashboard.js file]

NEW TAB: "active" (show before "cameras" tab)

REQUIREMENTS:

1. TAB BUTTON:
   Add before existing "cameras" tab:
   - Icon: Camera
   - Label: "Active Cameras"
   - Badge: Show count of online cameras

2. ACTIVE CAMERAS VIEW:
   
   A. Data Source:
      - Collection: cameras (not pending_cameras)
      - Real-time: Use onSnapshot
      - Filter by role:
        * Superadmin: All cameras
        * Subadmin: Where camera.subadminId == userId
        * Viewer: Where cameraId in assignedCameras

   B. Camera Card:
      - Camera name
      - Site name (lookup from sites)
      - Status indicator:
        * Green dot + "Online" if lastSeen < 5 min
        * Red dot + "Offline" if lastSeen >= 5 min
      - Last seen: "2 minutes ago" (use date-fns)
      - Today's count summary (query counts subcollection)
      - Click card → navigate to detail (coming later)

   C. Summary Stats (top of page):
      - Total Cameras: X
      - Online: X (green)
      - Offline: X (red)
      - Today's Total Count: X,XXX

   D. Filters:
      - Dropdown: All Sites / [specific site]
      - Dropdown: All Status / Online / Offline
      - Search: Filter by camera name

3. TODAY'S COUNTS QUERY:
```javascript
// For each camera, query:
cameras/{cameraId}/counts/{timestamp}
  where timestamp >= startOfToday
  aggregate sum of counts
```

4. STYLING:
   - Match existing card style
   - Use lucide-react icons
   - Responsive grid
   - Loading skeleton
   - Empty state

5. NO BREAKING CHANGES:
   - Keep all existing tabs
   - Keep all existing state
   - Keep all existing functions

Generate the enhanced Dashboard.js with Active Cameras tab.
```

---

### PROMPT 4: Provisioning Tokens Tab

```
Add "Provisioning" tab to my Dashboard.js for token-based camera registration.

REQUIREMENTS:

1. NEW TAB: "provisioning" (after "subadmins" tab)
   - Only visible to superadmin
   - Icon: Key or QrCode
   - Label: "Provisioning"

2. TOKEN LIST:
   
   A. Data Source:
      - Collection: provisioningTokens
      - Real-time updates
      - Order by: createdAt desc

   B. Token Card:
      - Token string (PT_XXXXXXXXXXXX)
      - Camera name (pre-defined)
      - Site name (lookup)
      - Status badge:
        * Yellow: Pending
        * Green: Used
        * Red: Revoked
        * Gray: Expired
      - Created: date
      - Expires: date (show countdown if pending)
      - Assigned Camera ID (if used)
      - Actions:
        * View QR (if pending)
        * Revoke (if pending)
        * Delete (if revoked/expired)

3. GENERATE TOKEN DIALOG:
   
   A. Button: "Generate Token" (top right)
   
   B. Form Fields:
      - Camera Name (text input) *
      - Select Site (dropdown) *
      - Expiry Days (number input, default 7)
   
   C. On Submit:
      - Call Cloud Function: generateProvisioningToken
      - Show success modal with:
        * Token string (copyable)
        * QR Code (using qrcode.react)
        * Download QR button
        * Print button
        * Close button

4. QR CODE:
   - Use qrcode.react library
   - QR data format:
```json
{
  "action": "provision_camera",
  "token": "PT_XXXXXXXXXXXX",
  "server": "https://provision.yourcompany.com"
}
```

5. DOWNLOAD QR:
   - Generate PNG from canvas
   - Filename: {cameraName}-QR.png

6. CLOUD FUNCTION CALL:
```javascript
const generateProvisioningToken = httpsCallable(
  functions, 
  'generateProvisioningToken'
);

const result = await generateProvisioningToken({
  cameraName,
  siteId,
  expiryDays
});
```

7. STYLING:
   - Match existing modals
   - Token cards in grid
   - Status badge colors
   - Large QR code (300x300)

Generate the Provisioning tab component.
```

---

### PROMPT 5: Analytics Dashboard

```
Add "Analytics" tab to my Dashboard.js with charts and reports.

REQUIREMENTS:

1. NEW TAB: "analytics"
   - Icon: BarChart or TrendingUp
   - Label: "Analytics"
   - Visible to all roles (filtered data)

2. DEPENDENCIES:
   - recharts (already installed)
   - date-fns (already installed)

3. PAGE LAYOUT:

   A. Summary Cards (Top Row):
      - Today's Total Count
      - This Week's Total
      - Average Daily Count
      - Top Camera (by count)

   B. Date Range Picker:
      - Presets: Today, Yesterday, Last 7 Days, Last 30 Days, Custom
      - Use date-fns for date handling

   C. Filter Row:
      - Site Selector (All Sites / specific)
      - Camera Selector (All Cameras / specific)
      - Object Type (All / Person / Vehicle / etc)

4. CHARTS (using recharts):

   A. Line Chart: Counts Over Time
      - X-axis: Time (hourly for today, daily for week+)
      - Y-axis: Count
      - Multiple lines for different object types
      - Tooltip with details
      - Responsive height (400px)

   B. Bar Chart: Hourly Breakdown (for single day)
      - X-axis: Hour (0-23)
      - Y-axis: Count
      - Stacked bars by object type
      - Colors: person=blue, vehicle=green, etc

   C. Pie Chart: Object Type Distribution
      - Segments: Different object types
      - Percentages shown
      - Legend on right

5. DATA QUERIES:

```javascript
// Query structure:
cameras/{cameraId}/counts/{timestamp}
  where timestamp >= startDate
  where timestamp <= endDate
  
// For superadmin: query all cameras
// For subadmin: query cameras where subadminId == userId
// For viewer: query cameras where cameraId in assignedCameras

// Aggregate counts by time period
```

6. EXPORT BUTTONS:
   - Export to CSV (with date range in filename)
   - Export to PDF (chart screenshot + data table)

7. STYLING:
   - Clean, modern charts
   - Responsive containers
   - Loading skeletons
   - Empty state with helpful message

8. PERFORMANCE:
   - Limit queries to selected date range
   - Cache data locally
   - Show loading indicators

Generate the Analytics tab component with all charts.
```

---

## INSTALLATION COMMANDS

```bash
# 1. Dashboard dependencies
cd web-dashboard
npm install recharts qrcode.react date-fns react-router-dom

# 2. Initialize Firebase Functions
cd ..
firebase init functions
# Choose TypeScript, ESLint Yes

# 3. Install function dependencies
cd functions
npm install crypto uuid

# 4. Deploy security rules
firebase deploy --only firestore:rules

# 5. Test in emulator first
cd functions
npm run serve
# In another terminal:
cd web-dashboard
npm start

# 6. Deploy everything when ready
cd ..
firebase deploy
```

---

## TESTING CHECKLIST

After each prompt:

□ Prompt 1: Cloud Functions
  - Deploy functions
  - Test createSuperadmin
  - Test createSubadmin
  - Test createViewer
  - Test approveCamera

□ Prompt 2: App.js Enhancement
  - Login as superadmin → superadmin site works
  - Login as subadmin → subadmin site works
  - Create viewer → login → subadmin site works
  - Wrong role → correct site = access denied

□ Prompt 3: Active Cameras Tab
  - See all cameras (superadmin)
  - See filtered cameras (subadmin/viewer)
  - Real-time status updates
  - Filters work

□ Prompt 4: Provisioning Tab
  - Generate token
  - QR code displays
  - Download QR works
  - Token list updates

□ Prompt 5: Analytics Tab
  - Charts render
  - Data filters work
  - Export works
  - Role filtering works

---

## NEXT STEPS AFTER THESE 5 PROMPTS

Once these are working, we'll add:

6. Camera Detail Page with Zone Configuration
7. Alert System
8. Camera Status Monitoring
9. Advanced Reporting

---

## SUMMARY

**Before Starting:**
1. ✅ Install dashboard dependencies
2. ✅ Initialize Firebase Functions
3. ✅ Deploy enhanced security rules

**Then Use Prompts:**
1. Cloud Functions (backend foundation)
2. App.js Enhancement (viewer role)
3. Active Cameras Tab (main dashboard)
4. Provisioning Tab (QR tokens)
5. Analytics Tab (charts & reports)

**Each prompt is:**
- Copy-paste ready
- Integrated with your existing code
- Non-breaking
- Fully functional

Ready to start! 🚀
