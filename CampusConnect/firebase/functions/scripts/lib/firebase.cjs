const admin = require('firebase-admin');

function initFirestore() {
  if (admin.apps.length === 0) {
    const options = {};

    if (process.env.FIREBASE_PROJECT_ID) {
      options.projectId = process.env.FIREBASE_PROJECT_ID;
    }

    admin.initializeApp(options);
  }

  return admin.firestore();
}

module.exports = {
  admin,
  initFirestore,
};
