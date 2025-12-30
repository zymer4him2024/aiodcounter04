#!/usr/bin/env node

/**
 * Setup script to create the first superadmin account
 * 
 * Usage:
 *   node scripts/setup-superadmin.js <email> <password> <name> <companyName>
 * 
 * Example:
 *   node scripts/setup-superadmin.js admin@example.com password123 "Admin User" "My Company"
 */

const admin = require('firebase-admin');
const readline = require('readline');

// Initialize Firebase Admin
// Make sure to set GOOGLE_APPLICATION_CREDENTIALS or use service account
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

async function createSuperadmin() {
  let email, password, name, companyName;

  // Get arguments from command line or prompt
  if (process.argv.length >= 6) {
    [, , email, password, name, companyName] = process.argv;
  } else {
    console.log('=== Create First Superadmin Account ===\n');
    email = await question('Email: ');
    password = await question('Password: ');
    name = await question('Name: ');
    companyName = await question('Company Name: ');
  }

  if (!email || !password || !name || !companyName) {
    console.error('Error: All fields are required');
    rl.close();
    process.exit(1);
  }

  try {
    const db = admin.firestore();

    // Check if superadmins already exist
    const superadminsSnapshot = await db.collection('superadmins').limit(1).get();
    if (!superadminsSnapshot.empty) {
      console.log('\n⚠️  Warning: Superadmins already exist.');
      const proceed = await question('Continue anyway? (y/N): ');
      if (proceed.toLowerCase() !== 'y') {
        console.log('Cancelled.');
        rl.close();
        process.exit(0);
      }
    }

    // Check if user exists
    let userRecord;
    try {
      userRecord = await admin.auth().getUserByEmail(email);
      console.log(`\n✓ User with email ${email} already exists. Updating...`);
      
      // Check if already superadmin
      const existingSuperadmin = await db.collection('superadmins').doc(userRecord.uid).get();
      if (existingSuperadmin.exists) {
        console.error(`\n❌ Error: ${email} is already a superadmin`);
        rl.close();
        process.exit(1);
      }
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        // Create new user
        userRecord = await admin.auth().createUser({
          email,
          password,
          displayName: name,
        });
        console.log(`\n✓ Created new Firebase Auth user: ${userRecord.uid}`);
      } else {
        throw error;
      }
    }

    // Set custom claim
    await admin.auth().setCustomUserClaims(userRecord.uid, {
      role: 'superadmin'
    });
    console.log('✓ Set custom claim: role = superadmin');

    // Create Firestore document
    await db.collection('superadmins').doc(userRecord.uid).set({
      email,
      name,
      companyName,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      role: 'superadmin'
    });
    console.log('✓ Created Firestore document in superadmins collection');

    console.log('\n✅ Superadmin created successfully!');
    console.log(`\nYou can now login with:`);
    console.log(`  Email: ${email}`);
    console.log(`  Password: ${password}`);
    console.log(`\nNote: The user may need to sign out and sign in again for custom claims to take effect.`);

  } catch (error) {
    console.error('\n❌ Error creating superadmin:', error.message);
    if (error.code) {
      console.error(`   Error code: ${error.code}`);
    }
    process.exit(1);
  } finally {
    rl.close();
  }
}

createSuperadmin();







