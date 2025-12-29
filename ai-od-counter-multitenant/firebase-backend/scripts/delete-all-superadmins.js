#!/usr/bin/env node

/**
 * Script to delete ALL superadmin accounts
 * Use with caution!
 */

// Use firebase-admin from functions/node_modules
const path = require('path');
const adminPath = path.join(__dirname, '../functions/node_modules/firebase-admin');
const admin = require(adminPath);

// Initialize Firebase Admin
if (!admin.apps.length) {
  try {
    admin.initializeApp();
  } catch (error) {
    console.error('Error initializing Firebase Admin:', error.message);
    console.error('\nMake sure you have:');
    console.error('1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable, OR');
    console.error('2. Place service account JSON in the project root as "serviceAccountKey.json"');
    process.exit(1);
  }
}

async function deleteAllSuperadmins() {
  try {
    const db = admin.firestore();
    const superadminsSnapshot = await db.collection('superadmins').get();

    if (superadminsSnapshot.empty) {
      console.log('\nNo superadmins found.');
      return;
    }

    console.log(`\nFound ${superadminsSnapshot.size} superadmin(s).`);
    
    for (const doc of superadminsSnapshot.docs) {
      const data = doc.data();
      const uid = doc.id;
      
      console.log(`\nDeleting: ${data.email} (${uid})`);
      
      try {
        // Delete from Firestore
        await db.collection('superadmins').doc(uid).delete();
        console.log('  ✓ Deleted from Firestore');

        // Remove custom claims
        try {
          await admin.auth().setCustomUserClaims(uid, null);
          console.log('  ✓ Removed custom claims');
        } catch (error) {
          if (error.code !== 'auth/user-not-found') {
            console.log('  ⚠ Could not remove claims:', error.message);
          }
        }

        // Delete from Firebase Auth
        try {
          await admin.auth().deleteUser(uid);
          console.log('  ✓ Deleted from Firebase Auth');
        } catch (error) {
          if (error.code !== 'auth/user-not-found') {
            console.log('  ⚠ Could not delete from Auth:', error.message);
          }
        }
      } catch (error) {
        console.error(`  ❌ Error deleting ${data.email}:`, error.message);
      }
    }

    console.log('\n✅ All superadmins deleted!');
    console.log('\nYou can now create a new superadmin using the setup screen.');

  } catch (error) {
    console.error('\n❌ Error:', error.message);
    if (error.code) {
      console.error(`   Error code: ${error.code}`);
    }
    process.exit(1);
  }
}

deleteAllSuperadmins();






