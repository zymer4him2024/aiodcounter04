# Setup Guide

## Initial Setup - Create First Superadmin

You have two options to create the first superadmin account:

### Option 1: Using the Web Dashboard (Recommended)

1. Start the React app:
   ```bash
   cd web-dashboard
   npm start
   ```

2. Open your browser to `http://localhost:3000`

3. If no superadmins exist, you'll see the "Setup First Superadmin" screen

4. Fill in the form:
   - Name: Your full name
   - Email: Your email address
   - Password: At least 6 characters
   - Company Name: Your company name

5. Click "Create Superadmin"

6. You'll be redirected to the login page - use the credentials you just created

### Option 2: Using the CLI Script

1. Make sure you have Firebase Admin credentials set up:
   - Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable to your service account JSON file, OR
   - Place `serviceAccountKey.json` in the `firebase-backend` directory

2. Run the setup script:
   ```bash
   cd firebase-backend
   node scripts/setup-superadmin.js
   ```

3. Follow the prompts, or provide arguments:
   ```bash
   node scripts/setup-superadmin.js admin@example.com password123 "Admin User" "My Company"
   ```

## Deploy Firebase Functions

After making changes to the functions, deploy them:

```bash
cd firebase-backend
firebase deploy --only functions
```

## Testing the System

1. **Login as Superadmin**
   - Use the credentials you created during setup
   - You should see all tabs: Cameras, Sites, Subadmins

2. **Create a Subadmin**
   - Go to Subadmins tab
   - Click "Create Subadmin"
   - Fill in the form and submit

3. **Create a Site**
   - Go to Sites tab
   - Click "Create Site"
   - Fill in name, location, and assign to a subadmin

4. **Approve Cameras**
   - Go to Cameras tab
   - When a Raspberry Pi registers, it will appear here
   - Click "Approve" to activate it

## Troubleshooting

### "Missing or insufficient permissions" error
- Make sure you're logged in as a superadmin
- Check that custom claims are set correctly (you may need to sign out and sign in again)

### Functions not working
- Make sure functions are deployed: `firebase deploy --only functions`
- Check Firebase Console → Functions for any errors

### Can't create superadmin
- If superadmins already exist, you need a setup token
- Set `SETUP_TOKEN` environment variable in Firebase Functions config
- Or use the CLI script with proper credentials

## Next Steps

- Test camera registration flow
- Create test sites and subadmins
- Verify camera approval works end-to-end







