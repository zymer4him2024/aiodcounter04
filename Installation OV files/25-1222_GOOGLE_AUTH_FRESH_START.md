# GOOGLE AUTHENTICATION IMPLEMENTATION
## Complete Reset & Fresh Start

---

## CURRENT SITUATION

✅ **What You Have:**
- Firebase Google Auth enabled
- Login.js with Google sign-in
- No superadmin exists yet (fresh start)

🎯 **What We'll Build:**
- First Google user becomes superadmin automatically
- Additional users created by superadmin
- Role assignment via custom claims
- Multi-site access control

---

## STEP 1: FIREBASE CONSOLE SETUP

### Enable Google Authentication

1. Go to Firebase Console: https://console.firebase.google.com
2. Select project: **aiodcouter04**
3. Navigate to: **Authentication** → **Sign-in method**
4. Enable: **Google**
5. Add authorized domains:
   - `aiodcouter04-superadmin.web.app`
   - `aiodcouter04-superadmin.firebaseapp.com`
   - `aiodcouter04-subadmin.web.app`
   - `aiodcouter04-subadmin.firebaseapp.com`
   - `localhost` (for development)

---

## STEP 2: UPDATED FIRESTORE RULES (FRESH START)

Replace your entire `firestore.rules` file:

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
    
    function hasNoRole() {
      return isAuthenticated() && 
             !('role' in request.auth.token);
    }
    
    function isValidCameraToken() {
      return isAuthenticated() && 
             request.auth.token.deviceToken != null;
    }
    
    // ===== SUPERADMINS =====
    
    // Allow anyone to check if collection is empty (for first-time setup)
    match /superadmins {
      allow list: if true; // For setup detection
    }
    
    match /superadmins/{adminId} {
      // Allow authenticated users with no role to check if they should be superadmin
      allow read: if isAuthenticated();
      // Only Cloud Functions can write
      allow write: if false;
    }
    
    // ===== SUBADMINS =====
    
    match /subadmins/{subadminId} {
      allow read: if isSuperadmin() || (isSubadmin() && request.auth.uid == subadminId);
      allow write: if isSuperadmin();
    }
    
    match /subadmins {
      allow list: if isSuperadmin();
    }
    
    // ===== VIEWERS =====
    
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
                     isViewer();
      allow write: if isSuperadmin();
    }
    
    match /sites {
      allow list: if isSuperadmin() || isSubadmin() || isViewer();
    }
    
    // ===== PENDING CAMERAS =====
    
    match /pending_cameras/{deviceId} {
      allow create: if request.resource.data.deviceId == deviceId &&
                       request.resource.data.status == 'pending';
      allow update: if request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['lastSeen']);
      allow read, delete: if isSuperadmin();
    }
    
    match /pending_cameras {
      allow list: if isSuperadmin();
    }
    
    // ===== ACTIVE CAMERAS =====
    
    match /cameras/{cameraId} {
      allow read: if isSuperadmin() || 
                     (isSubadmin() && resource.data.subadminId == request.auth.uid) ||
                     (isViewer() && cameraId in request.auth.token.assignedCameras);
      allow write: if isSuperadmin();
      
      // Allow camera devices to update status
      allow update: if isValidCameraToken() && 
                       request.resource.data.diff(resource.data).affectedKeys()
                         .hasOnly(['status', 'lastSeen', 'ipAddress']);
      
      // ===== COUNTS SUBCOLLECTION =====
      match /counts/{timestamp} {
        allow read: if isSuperadmin() || 
                       (isSubadmin() && get(/databases/$(database)/documents/cameras/$(cameraId)).data.subadminId == request.auth.uid) ||
                       (isViewer() && cameraId in request.auth.token.assignedCameras);
        allow create: if isValidCameraToken();
        allow update, delete: if false; // Immutable
      }
    }
    
    match /cameras {
      allow list: if isSuperadmin() || isSubadmin() || isViewer();
    }
    
    // ===== PROVISIONING TOKENS =====
    
    match /provisioningTokens/{token} {
      allow read, write: if isSuperadmin();
      allow read: if isAuthenticated(); // RPi needs to validate during activation
    }
    
    match /provisioningTokens {
      allow list: if isSuperadmin();
    }
    
    // ===== ALERT RULES =====
    
    match /alertRules/{ruleId} {
      allow read: if isSuperadmin() || isSubadmin();
      allow write: if isSuperadmin();
    }
    
    match /alertRules {
      allow list: if isSuperadmin() || isSubadmin();
    }
    
    // ===== ALERTS =====
    
    match /alerts/{alertId} {
      allow read: if isSuperadmin() || isSubadmin() || isViewer();
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

## STEP 3: UPDATED APP.JS (GOOGLE AUTH)

Replace your entire `App.js`:

```javascript
import React, { useState, useEffect } from 'react';
import { onAuthStateChanged } from 'firebase/auth';
import { collection, getDocs, doc, getDoc } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { auth, db, functions } from './firebase';
import Login from './Login';
import Dashboard from './Dashboard';
import './App.css';

// Detect which hosting site we're on
const getHostingSite = () => {
  const hostname = window.location.hostname;
  if (hostname.includes('superadmin') || 
      hostname === 'aiodcouter04-superadmin.web.app' || 
      hostname === 'aiodcouter04-superadmin.firebaseapp.com') {
    return 'superadmin';
  }
  return 'subadmin';
};

const HOSTING_SITE = getHostingSite();

const ROLES = {
  SUPERADMIN: 'superadmin',
  SUBADMIN: 'subadmin',
  VIEWER: 'viewer'
};

function App() {
  const [user, setUser] = useState(null);
  const [userRole, setUserRole] = useState(null);
  const [loading, setLoading] = useState(true);
  const [checkingSetup, setCheckingSetup] = useState(true);
  const [needsFirstSuperadmin, setNeedsFirstSuperadmin] = useState(false);
  const [creatingFirstSuperadmin, setCreatingFirstSuperadmin] = useState(false);

  // Check if we need first superadmin (only on superadmin site)
  useEffect(() => {
    if (HOSTING_SITE === 'subadmin') {
      setNeedsFirstSuperadmin(false);
      setCheckingSetup(false);
      return;
    }

    const checkSuperadmins = async () => {
      try {
        console.log('[App] Checking for superadmins...');
        const superadminsSnapshot = await getDocs(collection(db, 'superadmins'));
        const isEmpty = superadminsSnapshot.empty;
        
        console.log(`[App] Superadmins found: ${superadminsSnapshot.size}`);
        setNeedsFirstSuperadmin(isEmpty);
      } catch (error) {
        console.error('[App] Error checking superadmins:', error);
        setNeedsFirstSuperadmin(true); // Safer to assume setup needed
      } finally {
        setCheckingSetup(false);
      }
    };

    checkSuperadmins();
  }, []);

  // Handle authentication state
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (currentUser) => {
      console.log('[App] Auth state:', currentUser ? currentUser.email : 'no user');
      
      if (currentUser) {
        setUser(currentUser);

        // Check if this is first superadmin scenario
        if (needsFirstSuperadmin && HOSTING_SITE === 'superadmin') {
          console.log('[App] First user logged in, creating superadmin...');
          await createFirstSuperadmin(currentUser);
          return;
        }

        // Get user role from custom claims
        try {
          await new Promise(resolve => setTimeout(resolve, 500));
          await currentUser.getIdToken(true);
          const idTokenResult = await currentUser.getIdTokenResult();
          const role = idTokenResult.claims.role || null;
          
          console.log('[App] User role:', role);
          console.log('[App] Hosting site:', HOSTING_SITE);

          // Validate role matches hosting site
          if (HOSTING_SITE === 'superadmin' && role !== ROLES.SUPERADMIN) {
            console.warn('[App] Not a superadmin on superadmin site');
            setUserRole(null);
          } else if (HOSTING_SITE === 'subadmin' && 
                     ![ROLES.SUBADMIN, ROLES.VIEWER].includes(role)) {
            console.warn('[App] Invalid role for subadmin site');
            setUserRole(null);
          } else {
            setUserRole(role);
          }

          // If no role but should have one, check Firestore
          if (!role && !needsFirstSuperadmin) {
            console.log('[App] No role in claims, checking Firestore...');
            const userDoc = await getDoc(doc(db, 'superadmins', currentUser.uid));
            if (userDoc.exists()) {
              console.log('[App] User exists in Firestore, refreshing token...');
              await new Promise(resolve => setTimeout(resolve, 2000));
              await currentUser.getIdToken(true);
              const refreshedResult = await currentUser.getIdTokenResult();
              setUserRole(refreshedResult.claims.role || null);
            }
          }
        } catch (error) {
          console.error('[App] Error getting role:', error);
          setUserRole(null);
        }
      } else {
        setUser(null);
        setUserRole(null);
      }
      
      setLoading(false);
    });

    return () => unsubscribe();
  }, [needsFirstSuperadmin]);

  // Create first superadmin
  const createFirstSuperadmin = async (currentUser) => {
    setCreatingFirstSuperadmin(true);
    try {
      console.log('[App] Creating first superadmin...');
      
      const createFirstSuperadminFn = httpsCallable(functions, 'createFirstSuperadmin');
      await createFirstSuperadminFn({
        uid: currentUser.uid,
        email: currentUser.email,
        name: currentUser.displayName || currentUser.email.split('@')[0],
        photoURL: currentUser.photoURL
      });

      console.log('[App] First superadmin created successfully');
      
      // Refresh token to get new claims
      await new Promise(resolve => setTimeout(resolve, 2000));
      await currentUser.getIdToken(true);
      const idTokenResult = await currentUser.getIdTokenResult();
      
      setUserRole(idTokenResult.claims.role);
      setNeedsFirstSuperadmin(false);
      
    } catch (error) {
      console.error('[App] Error creating first superadmin:', error);
      alert('Failed to create superadmin account: ' + error.message);
    } finally {
      setCreatingFirstSuperadmin(false);
    }
  };

  // Debug logging
  useEffect(() => {
    console.log('[App] State:', {
      hostingSite: HOSTING_SITE,
      checkingSetup,
      loading,
      needsFirstSuperadmin,
      hasUser: !!user,
      userRole,
      creatingFirstSuperadmin
    });
  }, [checkingSetup, loading, needsFirstSuperadmin, user, userRole, creatingFirstSuperadmin]);

  // Loading state
  if (checkingSetup || loading || creatingFirstSuperadmin) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh',
        backgroundColor: '#f9fafb',
        flexDirection: 'column',
        gap: '1rem'
      }}>
        <div style={{ fontSize: '1.25rem', color: '#6b7280' }}>
          {creatingFirstSuperadmin ? 'Setting up first superadmin...' : 'Loading...'}
        </div>
      </div>
    );
  }

  // Show login if no user
  if (!user) {
    return <Login />;
  }

  // If user has no role, show appropriate message
  if (!userRole) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh',
        backgroundColor: '#f9fafb',
        flexDirection: 'column',
        gap: '1rem',
        padding: '2rem'
      }}>
        <div style={{ fontSize: '1.25rem', color: '#991b1b', fontWeight: '600' }}>
          Access Denied
        </div>
        <div style={{ fontSize: '0.875rem', color: '#6b7280', textAlign: 'center', maxWidth: '400px' }}>
          {HOSTING_SITE === 'superadmin' 
            ? 'This site is for superadmins only. You do not have superadmin access.'
            : 'You do not have permission to access this site. Please contact your administrator.'}
        </div>
        <button
          onClick={() => auth.signOut()}
          style={{
            padding: '0.75rem 1.5rem',
            backgroundColor: '#ef4444',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '0.875rem',
            fontWeight: '600',
            marginTop: '1rem'
          }}
        >
          Sign Out
        </button>
      </div>
    );
  }

  // Validate role matches site
  if (HOSTING_SITE === 'superadmin' && userRole !== ROLES.SUPERADMIN) {
    return (
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        alignItems: 'center', 
        height: '100vh',
        backgroundColor: '#f9fafb',
        flexDirection: 'column',
        gap: '1rem',
        padding: '2rem'
      }}>
        <div style={{ fontSize: '1.25rem', color: '#991b1b', fontWeight: '600' }}>
          Access Denied
        </div>
        <div style={{ fontSize: '0.875rem', color: '#6b7280', textAlign: 'center', maxWidth: '400px' }}>
          This site is for superadmins only. Your role: <strong>{userRole}</strong>
        </div>
        <button
          onClick={() => auth.signOut()}
          style={{
            padding: '0.75rem 1.5rem',
            backgroundColor: '#ef4444',
            color: 'white',
            border: 'none',
            borderRadius: '8px',
            cursor: 'pointer',
            fontSize: '0.875rem',
            fontWeight: '600',
            marginTop: '1rem'
          }}
        >
          Sign Out
        </button>
      </div>
    );
  }

  // Show dashboard
  return <Dashboard user={user} userRole={userRole} />;
}

export default App;
```

---

## STEP 4: UPDATED LOGIN.JS (GOOGLE AUTH)

Create/Replace `Login.js`:

```javascript
import React, { useState } from 'react';
import { signInWithPopup } from 'firebase/auth';
import { auth, googleProvider } from './firebase';

function Login() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleGoogleLogin = async () => {
    setLoading(true);
    setError(null);
    
    try {
      await signInWithPopup(auth, googleProvider);
      // App.js will handle the rest
    } catch (error) {
      console.error('Login error:', error);
      setError(error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      backgroundColor: '#f9fafb'
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '12px',
        boxShadow: '0 10px 40px rgba(0,0,0,0.1)',
        padding: '3rem',
        maxWidth: '400px',
        width: '90%'
      }}>
        <div style={{ textAlign: 'center', marginBottom: '2rem' }}>
          <h1 style={{ 
            fontSize: '1.875rem', 
            fontWeight: 'bold', 
            color: '#111827',
            marginBottom: '0.5rem'
          }}>
            AI Object Detection
          </h1>
          <p style={{ color: '#6b7280', fontSize: '0.875rem' }}>
            Multi-Tier Camera Management System
          </p>
        </div>

        {error && (
          <div style={{
            padding: '1rem',
            backgroundColor: '#fee2e2',
            border: '1px solid #fecaca',
            borderRadius: '8px',
            marginBottom: '1.5rem',
            color: '#991b1b',
            fontSize: '0.875rem'
          }}>
            {error}
          </div>
        )}

        <button
          onClick={handleGoogleLogin}
          disabled={loading}
          style={{
            width: '100%',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '0.75rem',
            padding: '0.875rem',
            backgroundColor: 'white',
            border: '2px solid #e5e7eb',
            borderRadius: '8px',
            fontSize: '1rem',
            fontWeight: '600',
            cursor: loading ? 'not-allowed' : 'pointer',
            transition: 'all 0.2s',
            opacity: loading ? 0.6 : 1
          }}
          onMouseEnter={(e) => {
            if (!loading) {
              e.target.style.borderColor = '#3b82f6';
              e.target.style.backgroundColor = '#f9fafb';
            }
          }}
          onMouseLeave={(e) => {
            e.target.style.borderColor = '#e5e7eb';
            e.target.style.backgroundColor = 'white';
          }}
        >
          <svg width="20" height="20" viewBox="0 0 24 24">
            <path
              fill="#4285F4"
              d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
            />
            <path
              fill="#34A853"
              d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            />
            <path
              fill="#FBBC05"
              d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"
            />
            <path
              fill="#EA4335"
              d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
            />
          </svg>
          {loading ? 'Signing in...' : 'Sign in with Google'}
        </button>

        <p style={{
          marginTop: '2rem',
          textAlign: 'center',
          fontSize: '0.75rem',
          color: '#9ca3af'
        }}>
          By signing in, you agree to our Terms of Service and Privacy Policy
        </p>
      </div>
    </div>
  );
}

export default Login;
```

---

## STEP 5: CLOUD FUNCTIONS (CURSOR PROMPT)

### PROMPT: Create Cloud Functions with Google Auth

```
Create Firebase Cloud Functions for my Google Auth-based camera system.

PROJECT INFO:
- Firebase project: aiodcouter04
- Authentication: Google Sign-In
- First user becomes superadmin automatically
- Additional users created by superadmin

COLLECTIONS:
- superadmins/{uid}
- subadmins/{uid}
- viewers/{uid}
- sites/{siteId}
- pending_cameras/{deviceId}
- cameras/{cameraId}
  - counts/{timestamp} (subcollection)
- provisioningTokens/{token}
- alertRules/{ruleId}
- alerts/{alertId}

FUNCTIONS TO CREATE:

1. createFirstSuperadmin (HTTPS callable)
   Input: { uid, email, name, photoURL }
   - Called when first user signs in with Google
   - Create superadmins/{uid} document
   - Set custom claims: { role: 'superadmin' }
   - Return success

2. createSubadmin (HTTPS callable)
   Input: { email, name }
   - Superadmin only
   - Send email invite link (no password needed - Google login)
   - When user signs in via link, auto-create subadmin role
   - Set custom claims: { role: 'subadmin', assignedSites: [] }
   - Create subadmins/{uid} document

3. createViewer (HTTPS callable)
   Input: { email, name, assignedCameras }
   - Superadmin only
   - Send email invite link
   - When user signs in via link, auto-create viewer role
   - Set custom claims: { role: 'viewer', assignedCameras: [...] }
   - Create viewers/{uid} document

4. approveCamera (HTTPS callable)
   Input: { deviceId, cameraName, siteId, subadminId }
   - Superadmin only
   - Move from pending_cameras to cameras
   - Generate device token
   - Set device custom claims: { deviceToken: 'xxx' }
   - Return camera ID and credentials

5. generateProvisioningToken (HTTPS callable)
   Input: { cameraName, siteId, expiryDays }
   - Superadmin only
   - Generate crypto-random token (PT_XXXXXXXXXXXX)
   - Store in provisioningTokens collection
   - Return token

6. provisionCamera (HTTPS request)
   URL: /api/v1/provision
   Input: { provisioningToken, deviceInfo }
   - Validate token
   - Create camera
   - Mark token as used
   - Return camera credentials

7. updateCameraStatus (scheduled, every 1 minute)
   - Check all cameras lastSeen
   - Mark offline if > 5 minutes

8. onUserCreated (Auth trigger)
   - Trigger on new Firebase Auth user
   - Check if invite exists
   - Auto-assign role based on invite

REQUIREMENTS:
- Use TypeScript
- Export from index.ts
- Validate all inputs
- Error handling
- Logging
- Use Firebase Admin SDK

DATA MODELS:

```typescript
interface Superadmin {
  uid: string;
  email: string;
  name: string;
  photoURL: string | null;
  createdAt: Timestamp;
}

interface Subadmin {
  uid: string;
  email: string;
  name: string;
  assignedSites: string[];
  createdAt: Timestamp;
  createdBy: string;
}

interface Viewer {
  uid: string;
  email: string;
  name: string;
  assignedCameras: string[];
  createdAt: Timestamp;
  createdBy: string;
}

interface Camera {
  id: string;
  name: string;
  siteId: string;
  subadminId: string;
  deviceId: string;
  macAddress: string;
  ipAddress: string;
  status: 'online' | 'offline';
  lastSeen: Timestamp;
  registeredAt: Timestamp;
  registeredBy: string;
  deviceToken: string;
}

interface ProvisioningToken {
  token: string;
  cameraName: string;
  siteId: string;
  subadminId: string;
  status: 'pending' | 'used' | 'revoked' | 'expired';
  createdAt: Timestamp;
  createdBy: string;
  expiresAt: Timestamp;
  usedAt: Timestamp | null;
  assignedCameraId: string | null;
}
```

Generate complete functions/src/index.ts with all functions.
```

---

## STEP 6: DEPLOYMENT

```bash
# 1. Deploy Firestore rules
firebase deploy --only firestore:rules

# 2. Deploy Cloud Functions
cd functions
npm run build
firebase deploy --only functions

# 3. Deploy dashboard
cd ../web-dashboard
npm run build
firebase deploy --only hosting
```

---

## STEP 7: TESTING FIRST SUPERADMIN

```
1. Clear all existing data:
   - Go to Firestore
   - Delete superadmins collection (if exists)
   - Delete subadmins collection (if exists)

2. Deploy everything (rules + functions)

3. Open: https://aiodcouter04-superadmin.web.app

4. Click "Sign in with Google"

5. Choose your Google account

6. App should:
   ✓ Detect no superadmins exist
   ✓ Call createFirstSuperadmin function
   ✓ Create your superadmin account
   ✓ Redirect to dashboard

7. Verify in Firestore:
   superadmins/{your-uid}
     - email: your@email.com
     - name: Your Name
     - role: superadmin (in custom claims)

8. Test logout and login again
   ✓ Should go straight to dashboard
   ✓ Role should persist
```

---

## STEP 8: INVITE WORKFLOW

### Creating Subadmin

```javascript
// In Dashboard.js, call this:
const createSubadmin = httpsCallable(functions, 'createSubadmin');
await createSubadmin({
  email: 'john@example.com',
  name: 'John Doe'
});

// Cloud Function:
// 1. Creates invite in Firestore
// 2. Sends email with sign-in link
// 3. When user signs in via link:
//    - onUserCreated trigger fires
//    - Auto-creates subadmin role
//    - User redirects to subadmin site
```

---

## SUMMARY

**FRESH START:**
1. ✅ First Google user = Superadmin (automatic)
2. ✅ No passwords needed (Google Auth)
3. ✅ Invite-based user creation
4. ✅ Multi-site access control
5. ✅ Custom claims for RBAC

**FILES TO UPDATE:**
1. `firestore.rules` (enhanced rules)
2. `App.js` (Google auth flow)
3. `Login.js` (Google sign-in button)
4. `functions/src/index.ts` (use Cursor prompt)

**NEXT STEPS:**
1. Deploy rules
2. Generate functions with Cursor
3. Deploy functions
4. Test first superadmin login
5. Test creating subadmins/viewers

Ready to reset and start fresh! 🚀
