# DASHBOARD.JS UPDATE INSTRUCTIONS

## ADD LIVE COUNTS TAB TO EXISTING DASHBOARD

### 1. Import LiveCounts Component

Add this import at the top of Dashboard.js (around line 10-15):

```javascript
import LiveCounts from './components/LiveCounts';
```

### 2. Add "Live Counts" to Tab State

Find the tab state management (around line 30-40) and add 'liveCounts':

```javascript
const [activeTab, setActiveTab] = useState('cameras'); // or 'liveCounts' as default
```

### 3. Add Live Counts Tab Button

Find the tab navigation section (around line 200-250) and add:

```javascript
<button
  onClick={() => setActiveTab('liveCounts')}
  className={`px-4 py-2 ${
    activeTab === 'liveCounts'
      ? 'border-b-2 border-blue-500 text-blue-600'
      : 'text-gray-500 hover:text-gray-700'
  }`}
>
  Live Counts
</button>
```

### 4. Add Live Counts Rendering

Find where tabs are rendered (around line 400-500) and add:

```javascript
{activeTab === 'liveCounts' && (
  <LiveCounts user={currentUser} />
)}
```

### COMPLETE EXAMPLE

Here's how the tab section should look:

```javascript
// Tab Navigation
<div className="flex gap-4 border-b">
  <button
    onClick={() => setActiveTab('cameras')}
    className={`px-4 py-2 ${activeTab === 'cameras' ? 'border-b-2 border-blue-500' : ''}`}
  >
    Cameras
  </button>
  
  <button
    onClick={() => setActiveTab('sites')}
    className={`px-4 py-2 ${activeTab === 'sites' ? 'border-b-2 border-blue-500' : ''}`}
  >
    Sites
  </button>
  
  <button
    onClick={() => setActiveTab('subadmins')}
    className={`px-4 py-2 ${activeTab === 'subadmins' ? 'border-b-2 border-blue-500' : ''}`}
  >
    Subadmins
  </button>
  
  <button
    onClick={() => setActiveTab('provisioning')}
    className={`px-4 py-2 ${activeTab === 'provisioning' ? 'border-b-2 border-blue-500' : ''}`}
  >
    Provisioning
  </button>
  
  {/* NEW TAB */}
  <button
    onClick={() => setActiveTab('liveCounts')}
    className={`px-4 py-2 ${activeTab === 'liveCounts' ? 'border-b-2 border-blue-500' : ''}`}
  >
    Live Counts
  </button>
</div>

// Tab Content
<div className="mt-6">
  {activeTab === 'cameras' && <CamerasTab />}
  {activeTab === 'sites' && <SitesTab />}
  {activeTab === 'subadmins' && <SubadminsTab />}
  {activeTab === 'provisioning' && <ProvisioningTab />}
  {activeTab === 'liveCounts' && <LiveCounts user={currentUser} />}
</div>
```

### FIREBASE CONFIG

Make sure your firebase.js exports the `db` instance:

```javascript
// src/firebase.js
import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';

const firebaseConfig = {
  projectId: "aiodcouter04",
  // ... other config
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app); // ← Make sure this is exported
```

### INSTALL RECHARTS (if not already installed)

```bash
npm install recharts
```

### BUILD AND DEPLOY

```bash
npm run build
firebase deploy --only hosting
```

---

## RESULT

After deployment, you'll have:

```
AI Object Detection Dashboard

[Cameras] [Sites] [Subadmins] [Provisioning] [Live Counts] ← NEW!

When clicked, shows:
- Camera selector
- Camera status (online/offline, FPS)
- Hardware monitoring (CPU temp, Hailo temp, memory)
- Latest counts (last 2 minutes)
- Historical charts (1h, 6h, 24h, 7d)
```

---

## TESTING

1. Deploy dashboard
2. Login as superadmin
3. Click "Live Counts" tab
4. Select a camera (should show if any approved cameras exist)
5. See hardware status (will show N/A until camera sends data)
6. Activate RPi camera to see live data

---

## DATA FLOW

```
RPi Camera Agent (with monitoring)
    ↓ (every 30 seconds)
Sends to Firestore: cameras/{cameraId}
    ↓
Live Counts Dashboard
    ↓ (real-time listener)
Displays: Temperature, FPS, Counts
```
