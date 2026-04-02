const {setGlobalOptions} = require("firebase-functions/v2");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

setGlobalOptions({maxInstances: 10});

admin.initializeApp();

exports.resetPasswordWithOtp = onCall(async (request) => {
  const data = request.data || {};
  const email = (data.email || "").toString().trim().toLowerCase();
  const otp = (data.otp || "").toString().trim();
  const newPassword = (data.newPassword || "").toString();

  if (!email || !otp || !newPassword) {
    throw new HttpsError(
        "invalid-argument",
        "Email, OTP and password are required",
    );
  }

  const otpRef = admin.firestore().collection("otp_codes").doc(email);
  const otpDoc = await otpRef.get();
  const otpData = otpDoc.data();

  if (!otpData) {
    throw new HttpsError("not-found", "OTP not found. Request a new code");
  }

  const savedOtp = (otpData.otp || "").toString().trim();
  const expiresAt = otpData.expiresAt;

  if (savedOtp !== otp) {
    throw new HttpsError("permission-denied", "Invalid OTP code");
  }

  if (!expiresAt || typeof expiresAt.toDate !== "function") {
    throw new HttpsError(
        "failed-precondition",
        "OTP has expired. Request a new code",
    );
  }

  if (Date.now() > expiresAt.toDate().getTime()) {
    throw new HttpsError(
        "failed-precondition",
        "OTP has expired. Request a new code",
    );
  }

  let userRecord;
  try {
    userRecord = await admin.auth().getUserByEmail(email);
  } catch (error) {
    if (error && error.code === "auth/user-not-found") {
      throw new HttpsError("not-found", "No account found");
    }
    throw new HttpsError("internal", "Failed to process password reset");
  }

  await admin.auth().updateUser(userRecord.uid, {
    password: newPassword,
    emailVerified: true,
  });

  await admin.firestore().collection("users").doc(userRecord.uid).set({
    isEmailVerified: true,
  }, {merge: true});

  await otpRef.delete();
  return {success: true};
});
