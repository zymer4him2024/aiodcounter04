const admin = require('firebase-admin');

// Initialize with default credentials (works if you're logged in with firebase CLI)
// Or use service account: admin.credential.cert(require('./service-account-key.json'))
admin.initializeApp({
  projectId: 'aiodcouter04'
});

const db = admin.firestore();

async function createSuperadmin() {
  // Replace with YOUR email
  const email = 'your-email@gmail.com';
  
  try {
    // Get user by email
    const user = await admin.auth().getUserByEmail(email);
    const uid = user.uid;
    
    console.log(`Found user: ${email} (${uid})`);
    
    // Check if superadmin already exists
    const superadmins = await db.collection('superadmins').limit(1).get();
    
    if (!superadmins.empty) {
      console.log('Superadmin already exists!');
      return;
    }
    
    // Create superadmin document
    await db.collection('superadmins').doc(uid).set({
      uid,
      email,
      name: user.displayName || email.split('@')[0],
      photoURL: user.photoURL || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, {
      role: 'superadmin'
    });
    
    console.log('✓ Superadmin created successfully!');
    console.log('✓ Custom claims set');
    console.log('Please logout and login again to refresh token');
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.error(`User with email ${email} not found. Please sign in with Google first.`);
    } else {
      throw error;
    }
  }
}

createSuperadmin()
  .then(() => process.exit(0))
  .catch(err => {
    console.error('Error:', err);
    process.exit(1);
  });






