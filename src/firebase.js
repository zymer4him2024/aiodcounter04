import { initializeApp } from 'firebase/app';
import { getFirestore } from 'firebase/firestore';
import { getFunctions } from 'firebase/functions';

const firebaseConfig = {
    apiKey: "AIzaSyAKCOYmCpOD2aGxDXHul50MPLK1GSrZBr8",
    authDomain: "aiodcouter04.firebaseapp.com",
    projectId: "aiodcouter04",
    storageBucket: "aiodcouter04.firebasestorage.app",
    messagingSenderId: "87816815492",
    appId: "1:87816815492:web:849f2866d2fd63baf393d1",
    measurementId: "G-6XQP98EXLR"
  };

const app = initializeApp(firebaseConfig);
export const db = getFirestore(app);
export const functions = getFunctions(app);