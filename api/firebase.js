// // firebase.js
// var admin = require("firebase-admin");

// var serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;

// if (!serviceAccount) {
//   throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable is not set');
// }

// admin.initializeApp({
//   credential: admin.credential.cert(JSON.parse(serviceAccount))
// });

// const db = admin.firestore();

// module.exports = db;
