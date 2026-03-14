const functions = require("firebase-functions");
const admin = require("firebase-admin");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'aicareerroadmap@gmail.com',
    pass: 'Sunaina@2004'
  }
});

exports.sendOtp = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const otp = Math.floor(100000 + Math.random() * 900000).toString();
  await db.collection('emailOtps').doc(email).set({
    otp,
    expires: Date.now() + 5 * 60 * 1000
  });
  await transporter.sendMail({
    from: '"AI Career Navigator" <youremail@gmail.com>',
    to: email,
    subject: "Your Sign-in OTP",
    text: `Your OTP: ${otp}`
  });
  return { success: true };
});

exports.verifyOtpAndIssueToken = functions.https.onCall(async (data, context) => {
  const email = data.email;
  const otp = data.otp;
  const record = await db.collection('emailOtps').doc(email).get();
  if (!record.exists || (Date.now() > record.data().expires)) {
    throw new functions.https.HttpsError('invalid-argument', 'OTP expired or missing');
  }
  if (record.data().otp !== otp) {
    throw new functions.https.HttpsError('permission-denied', 'Invalid OTP');
  }
  let user;
  try {
    user = await admin.auth().getUserByEmail(email);
  } catch (e) {
    user = await admin.auth().createUser({ email });
  }
  const token = await admin.auth().createCustomToken(user.uid);
  await db.collection('emailOtps').doc(email).delete();
  return { token };
});
