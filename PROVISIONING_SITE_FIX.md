# Provisioning Site Not Reachable - Fix Guide

## 🔍 Issue
The `/activate` route for camera provisioning is not accessible at:
- `https://aiodcounter04-superadmin.web.app/activate?token=XXX`

## ✅ Solution

### Step 1: Rebuild and Redeploy the Dashboard

The `ActivateCamera` component exists, but the app needs to be rebuilt and redeployed:

```bash
cd ai-od-counter-multitenant/web-dashboard

# Install dependencies (if needed)
npm install

# Build the app
npm run build

# Deploy to superadmin hosting
cd ..
firebase deploy --only hosting:superadmin
```

### Step 2: Verify Firebase Hosting Configuration

The `firebase.json` should have these rewrites to handle client-side routing:

```json
{
  "hosting": [
    {
      "target": "superadmin",
      "public": "web-dashboard/build",
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    }
  ]
}
```

**Verify:** Check `ai-od-counter-multitenant/firebase.json` - it should already have this.

### Step 3: Test the Route

After deployment, test:
1. **Direct URL:** `https://aiodcounter04-superadmin.web.app/activate?token=TEST_TOKEN_123`
2. **Expected behavior:**
   - Should show "Invalid or expired activation token" (if token doesn't exist)
   - Should load the activation form if token is valid

### Step 4: Check Browser Console

Open browser DevTools (F12) and check:
- Console for errors
- Network tab for failed requests
- Check if React app loads correctly

## 🔧 Troubleshooting

### Issue: Route Returns 404
**Cause:** Firebase hosting not serving `index.html` for all routes

**Fix:**
1. Verify `firebase.json` has the rewrite rule
2. Redeploy: `firebase deploy --only hosting:superadmin`
3. Wait 1-2 minutes for deployment to propagate

### Issue: Route Loads but Shows "Loading..."
**Cause:** Firestore query failing or token not found

**Fix:**
1. Check browser console for Firestore errors
2. Verify `provisioningTokens` collection exists in Firestore
3. Verify Firestore security rules allow public read access to `provisioningTokens`

### Issue: Component Not Found Error
**Cause:** `ActivateCamera` component not imported/built

**Fix:**
1. Verify `src/components/ActivateCamera.jsx` exists
2. Verify `src/App.js` imports it: `import ActivateCamera from './components/ActivateCamera';`
3. Rebuild: `npm run build`

### Issue: Blank Page
**Cause:** JavaScript errors preventing render

**Fix:**
1. Check browser console for errors
2. Verify all dependencies installed: `npm install`
3. Check if Firebase config is correct in `src/firebase.js`

## 📝 Quick Deploy Script

Create a quick deploy script:

```bash
#!/bin/bash
# deploy-provisioning.sh

cd ai-od-counter-multitenant/web-dashboard
echo "Building app..."
npm run build

if [ $? -eq 0 ]; then
  echo "Build successful. Deploying..."
  cd ..
  firebase deploy --only hosting:superadmin
  echo "✅ Deployment complete!"
  echo "Test: https://aiodcounter04-superadmin.web.app/activate?token=TEST"
else
  echo "❌ Build failed. Check errors above."
  exit 1
fi
```

## 🧪 Test Checklist

After deployment, verify:

- [ ] App loads at: `https://aiodcounter04-superadmin.web.app`
- [ ] Route loads at: `https://aiodcounter04-superadmin.web.app/activate?token=TEST`
- [ ] Shows error message if token is invalid (expected)
- [ ] Shows activation form if valid token is provided
- [ ] No console errors in browser DevTools
- [ ] Firestore connection works (check Network tab)

## 🔍 Verify Firestore Rules

Ensure `provisioningTokens` are readable without authentication:

```javascript
// firestore.rules
match /provisioningTokens/{tokenId} {
  allow read: if true; // Public read for activation
  allow write: if request.auth != null && 
    request.auth.token.role == 'superadmin';
}
```

## 📞 Next Steps

1. **Rebuild and deploy** the app (see Step 1)
2. **Wait 2-3 minutes** for deployment to complete
3. **Test the route** with a valid token
4. **Check Firestore** - ensure tokens are being created correctly

---

**Status:** Route configured, needs rebuild/deploy
**Last Updated:** December 28, 2024




