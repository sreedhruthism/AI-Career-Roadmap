import admin from "firebase-admin";
import nodemailer from "nodemailer";

// Init Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert({
      projectId: process.env.FIREBASE_PROJECT_ID,
      clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g,"-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCxWJHCArgFPZV1\n//WMgVL+mlQBoYA1LcszZmgR1Lp61W0fGq9u5ZxQiDpzX9xhIzgBkE1EuZoNlYME\nUMARSc15exiBHlq/DdlrX1Rb1n6EOy+EB0wtH1C8/Kkooh5Ey6ZF6r++MXGclOLH\nQdJy7BxU12RnDXNTfz70GS7PODgSE/4c8rs5/8k63PdQchvq9HSrUHikAf70cX4W\nzipcVkecv1NmGUMYP+drAIfNwl3Qqnosf8Iebo0qew/v4kz0CgusVvyAVLt0e3BT\n0mnJg8IQ44wY6HRNpTLO76MbSWH9Ltnvjkz4wtoODYX4kflfFTKMB8WHWAxG3BIS\nLb5XrX+7AgMBAAECggEAKXiyQSG8obEYiesMo0o8u8AgI+992TG3wnHQpVbPMtlE\n9tCZNMAp8SUiMge5M9f2CVuSzh7u+P09EZ3GhGRzUdSo0szj4Kie7r5wrjc3B7oF\nbwT72dNoYIFfF1rt5B2RaOkv5IyQalLgw0LPsUMojuh9mKGrFdv8Pz3CVf/qEMPL\nOb/MGgfiQdLA4zpdzj4BjlCYbcdVVYs0PuL7NI5iiWTz9ZMo2ld0S9+dGOZEIMT0\nLwcTCaCCFNk6ChAssvyfocwVd6/ciCVpvDVF98uTBhQ028rjy4vKtTw3eTKlcxvK\nKe3NKk2KJ7fcToS8VaE5HotDWDRg4dShGDgexD4YPQKBgQDjrBXkoUHmBXs5VM0Q\noFrNGvY9AA/QfwwYcIJpyfWsr41y/HqYp1v3KE23dfJy8eIN3F+SHrlTKAjfcH/I\nOpMdSWZgAWspegl0kTT4VlBrb3YMHNCCCuQ9qJeHXnbBAioWJ8KHonYmyw9KJjbj\nYyMjUSGCAUWxbzHcTphdO5BTHQKBgQDHaXh9iGWeKIcbGczEHxSiVqU0pLoLkMpR\npRKdMRLwATCeLhWGj3QzsJrtZlSU5syu9odNJPDXIatchEJGZgFMX7iBgXAEwKy7\n6i/k6H8i/K3Je7FSnI/1wk/6cHDdeHJDttM6SitANRHk4wR8SGhyPVtg8LllL+vX\njg9JZoiOtwKBgQCsjtlpF+/ib3Ud1vA2EdPAcRcA1PMni6OXQm8Vz0StRcFnzYT9\n/prtkVaWHodMJ5i1+LlW/oJoTIetEo9HK14lbGRzj5+xKBXSi9wh/Qmm5CwMsio2\n5hpnwUhYCXjogMN1V11RgAkdDfrgsGYZoiIXun4zEtPH0Adyev9wapzQ4QKBgGiP\niTpplr8DiTRQpun/UhZ9UEr2RQdjeHKvF7+Mx91JAnEuwOK5vbiM1e+9RIR/MLxd\nUDzHLfHgGbZ9MzMusWeWmWxurooPbYNrHInuzxtNWuLXFPe4WFQI+17aLpQyX9fZ\nuZBK67rTGPrnfqacYQfl3FBMaSoBoqx4NNPMC7apAoGBAMUQl89gdjbYaq+acmJG\nn0kB+bVzx9uWSv7k4YvGJWC3T6XdadOeqwWCP3zn1EcgfHBxWUFUiFg8rpJrUMfH\nhCmXepngoWwrD8O/WcXc5eHFLB/edPRAxzkRQ3mg3p/ZdAc/fgn/cOpRiNJH7fsF\nSI7e//FZDrOlxVLUyN9pBBGF\n-----END PRIVATE KEY-----\n",
    }),
  });
}

const db = admin.firestore();

// Gmail Transport
const transporter = nodemailer.createTransport({
  service: "gmail",
  auth: {
    user: process.env.EMAIL_USER,
    pass: process.env.EMAIL_PASS,
  },
});

export default async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: "Email required" });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Save to Firestore with expiry
    await db.collection("otps").doc(email).set({
      otp,
      expires: Date.now() + 5 * 60 * 1000,
    });

    // Send OTP email
    await transporter.sendMail({
      from: `"AI Career Navigator" <${process.env.EMAIL_USER}>`,
      to: email,
      subject: "Your Sign-in OTP",
      text: `Your OTP is ${otp}. It expires in 5 minutes.`,
    });

    return res.json({ success: true });
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
}
