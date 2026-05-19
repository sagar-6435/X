// Firebase Admin disabled — not configured
const admin = {
  messaging: () => ({
    send: async () => console.log('Firebase messaging disabled'),
  }),
};

module.exports = admin;
