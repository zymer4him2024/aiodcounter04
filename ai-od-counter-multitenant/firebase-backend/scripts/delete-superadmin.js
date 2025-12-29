#!/usr/bin/env node

/**
 * Script to delete a superadmin account
 * 
 * Usage:
 *   node scripts/delete-superadmin.js <email>
 * 
 * Example:
 *   node scripts/delete-superadmin.js admin@example.com
 */

// Use firebase-admin from functions/node_modules
const path = require('path');
const adminPath = path.join(__dirname, '../functions/node_modules/firebase-admin');
const admin = require(adminPath);
const readline = require('readline');

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

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

async function deleteSuperadmin() {
  let email;
  let force = false;

  // Parse arguments
  const args = process.argv.slice(2);
  if (args.includes('--force') || args.includes('-f')) {
    force = true;
    args.splice(args.indexOf('--force' || args.indexOf('-f')), 1);
  }

  // Get email from command line or prompt
  if (args.length >= 1) {
    email = args[0];
  } else {
    console.log('=== Delete Superadmin Account ===\n');
    email = await question('Email of superadmin to delete: ');
  }

  if (!email) {
    console.error('Error: Email is required');
    rl.close();
    process.exit(1);
  }

  try {
    const db = admin.firestore();

    // Find user by email
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
      console.log(`\n✓ Found user: ${userRecord.uid} (${userRecord.email})`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.error(`\n❌ Error: No user found with email ${email}`);
        rl.close();
        process.exit(1);
      } else {
        throw error;
      }
    }

    // Check if user is a superadmin
    const superadminDoc = await db.collection('superadmins').doc(userRecord.uid).get();
    if (!superadminDoc.exists) {
      console.error(`\n❌ Error: ${email} is not a superadmin`);
      rl.close();
      process.exit(1);
    }

    const superadminData = superadminDoc.data();
    console.log(`\nSuperadmin details:`);
    console.log(`  Name: ${superadminData.name}`);
    console.log(`  Company: ${superadminData.companyName}`);
    console.log(`  Created: ${superadminData.createdAt?.toDate() || 'Unknown'}`);

    // Confirm deletion (skip if --force flag)
    if (!force) {
      const confirm = await question(`\n⚠️  Are you sure you want to delete this superadmin? (yes/no): `);
      if (confirm.toLowerCase() !== 'yes') {
        console.log('Cancelled.');
        rl.close();
        process.exit(0);
      }
    } else {
      console.log('\n⚠️  Force flag detected - proceeding with deletion...');
    }

    // Delete from Firestore
    await db.collection('superadmins').doc(userRecord.uid).delete();
    console.log('✓ Deleted from Firestore (superadmins collection)');

    // Remove custom claims
    await admin.auth().setCustomUserClaims(userRecord.uid, null);
    console.log('✓ Removed custom claims');

    // Delete from Firebase Auth
    await admin.auth().deleteUser(userRecord.uid);
    console.log('✓ Deleted from Firebase Auth');

    console.log('\n✅ Superadmin deleted successfully!');
    console.log(`\nYou can now create a new superadmin using the setup screen.`);

  } catch (error) {
    console.error('\n❌ Error deleting superadmin:', error.message);
    if (error.code) {
      console.error(`   Error code: ${error.code}`);
    }
    process.exit(1);
  } finally {
    rl.close();
  }
}

deleteSuperadmin();

