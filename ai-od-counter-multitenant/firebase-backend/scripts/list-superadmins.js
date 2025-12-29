#!/usr/bin/env node

/**
 * Script to list all superadmin accounts
 * 
 * Run from firebase-backend/functions directory:
 *   node ../scripts/list-superadmins.js
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

async function listSuperadmins() {
  try {
    const db = admin.firestore();
    const superadminsSnapshot = await db.collection('superadmins').get();

    if (superadminsSnapshot.empty) {
      console.log('\nNo superadmins found.');
      return;
    }

    console.log('\n=== Superadmins ===\n');
    superadminsSnapshot.forEach((doc) => {
      const data = doc.data();
      console.log(`Email: ${data.email}`);
      console.log(`Name: ${data.name}`);
      console.log(`Company: ${data.companyName}`);
      console.log(`UID: ${doc.id}`);
      console.log(`Created: ${data.createdAt?.toDate() || 'Unknown'}`);
      console.log('---');
    });

  } catch (error) {
    console.error('\n❌ Error listing superadmins:', error.message);
    if (error.code) {
      console.error(`   Error code: ${error.code}`);
    }
    process.exit(1);
  }
}

listSuperadmins();

