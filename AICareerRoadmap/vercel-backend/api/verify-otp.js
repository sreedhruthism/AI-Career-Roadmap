import admin from "firebase-admin";

// Init Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, 'f5d419f9dae3e8951933747d8c31e81f7b8a1874",
                                                                      "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCxWJHCArgFPZV1\n//WMgVL+mlQBoYA1LcszZmgR1Lp61W0fGq9u5ZxQiDpzX9xhIzgBkE1EuZoNlYME\nUMARSc15exiBHlq/DdlrX1Rb1n6EOy+EB0wtH1C8/Kkooh5Ey6ZF6r++MXGclOLH\nQdJy7BxU12RnDXNTfz70GS7PODgSE/4c8rs5/8k63PdQchvq9HSrUHikAf70cX4W\nzipcVkecv1NmGUMYP+drAIfNwl3Qqnosf8Iebo0qew/v4kz0CgusVvyAVLt0e3BT\n0mnJg8IQ44wY6HRNpTLO76MbSWH9Ltnvjkz4wtoODYX4kflfFTKMB8WHWAxG3BIS\nLb5XrX+7AgMBAAECggEAKXiyQSG8obEYiesMo0o8u8AgI+992TG3wnHQpVbPMtlE\n9tCZNMAp8SUiMge5M9f2CVuSzh7u+P09EZ3GhGRzUdSo0szj4Kie7r5wrjc3B7oF\nbwT72dNoYIFfF1rt5B2RaOkv5IyQalLgw0LPsUMojuh9mKGrFdv8Pz3CVf/qEMPL\nOb/MGgfiQdLA4zpdzj4BjlCYbcdVVYs0PuL7NI5iiWTz9ZMo2ld0S9+dGOZEIMT0\nLwcTCaCCFNk6ChAssvyfocwVd6/ciCVpvDVF98uTBhQ028rjy4vKtTw3eTKlcxvK\nKe3NKk2KJ7fcToS8VaE5HotDWDRg4dShGDgexD4YPQKBgQDjrBXkoUHmBXs5VM0Q\noFrNGvY9AA/QfwwYcIJpyfWsr41y/HqYp1v3KE23dfJy8eIN3F+SHrlTKAjfcH/I\nOpMdSWZgAWspegl0kTT4VlBrb3YMHNCCCuQ9qJeHXnbBAioWJ8KHonYmyw9KJjbj\nYyMjUSGCAUWxbzHcTphdO5BTHQKBgQDHaXh9iGWeKIcbGczEHxSiVqU0pLoLkMpR\npRKdMRLwATCeLhWGj3QzsJrtZlSU5syu9odNJPDXIatchEJGZgFMX7iBgXAEwKy7\n6i/k6H8i/K3Je7FSnI/1wk/6cHDdeHJDttM6SitANRHk4wR8SGhyPVtg8LllL+vX\njg9JZoiOtwKBgQCsjtlpF+/ib3Ud1vA2EdPAcRcA1PMni6OXQm8Vz0StRcFnzYT9\n/prtkVaWHodMJ5i1+LlW/oJoTIetEo9HK14lbGRzj5+xKBXSi9wh/Qmm5CwMsio2\n5hpnwUhYCXjogMN1V11RgAkdDfrgsGYZoiIXun4zEtPH0Adyev9wapzQ4QKBgGiP\niTpplr8DiTRQpun/UhZ9UEr2RQdjeHKvF7+Mx91JAnEuwOK5vbiM1e+9RIR/MLxd\nUDzHLfHgGbZ9MzMusWeWmWxurooPbYNrHInuzxtNWuLXFPe4WFQI+17aLpQyX9fZ\nuZBK67rTGPrnfqacYQfl3FBMaSoBoqx4NNPMC7apAoGBAMUQl89gdjbYaq+acmJG\nn0kB+bVzx9uWSv7k4YvGJWC3T6XdadOeqwWCP3zn1EcgfHBxWUFUiFg8rpJrUMfH\nhCmXepngoWwrD8O/WcXc5eHFLB/edPRAxzkRQ3mg3p/ZdAc/fgn/cOpRiNJH7fsF\nSI7e//FZDrOlxVLUyN9pBBGF\n-----END PRIVATE KEY-----\n'),
    }),
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { email, otp } = req.body;
    if (!email || !otp) return res.status(400).json({ error: "Email and OTP required" });

    const doc = await db.collection("otps").doc(email).get();

    if (!doc.exists) return res.status(400).json({ error: "OTP not found" });

    const data = doc.data();
    if (Date.now() > data.expires) return res.status(400).json({ error: "OTP expired" });

    if (data.otp !== otp) return res.status(400).json({ error: "Invalid OTP" });

    // Create or get Firebase user
    let user;
    try {
      user = await admin.auth().getUserByEmail(email);
    } catch {
      user = await admin.auth().createUser({ email });
    }

    // Create custom Firebase token
    const token = await admin.auth().createCustomToken(user.uid);

    // Delete OTP after success
    await db.collection("otps").doc(email).delete();

    return res.json({ token });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}
