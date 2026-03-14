// server.js
import express from "express";
import mongoose from "mongoose";
import cors from "cors";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const app = express();
app.use(cors());
app.use(express.json());

// ✅ Fix __dirname in ES Module
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ✅ MongoDB Atlas connection
const mongoURI = "mongodb://akhilarya18_db_user:Akhilarya18@ac-pqt4v2i-shard-00-00.iwnjof0.mongodb.net:27017,ac-pqt4v2i-shard-00-01.iwnjof0.mongodb.net:27017,ac-pqt4v2i-shard-00-02.iwnjof0.mongodb.net:27017/AICareerRoadmapDB?ssl=true&replicaSet=atlas-125hr9-shard-0&authSource=admin&retryWrites=true&w=majority";
// ✅ Connect to MongoDB Atlas
mongoose
  .connect(mongoURI)
  .then(() => console.log("✅ Connected to MongoDB Atlas"))
  .catch((err) =>
    console.error(
      "❌ MongoDB connection error (will fallback to local JSON if needed):",
      err.message
    )
  );

// ✅ Define Schema
const KcetSchema = new mongoose.Schema({
  question_id: Number,
  question: String,
  options: [String],
  answer: String,
});

// ✅ Model (Collection: kcet_dataset)
const KcetModel = mongoose.model("kcet_dataset", KcetSchema, "kcet_dataset");

// ✅ Path to local fallback JSON
const localFilePath = path.join(__dirname, "assets", "kcet_questions.json");

// ✅ Route: Get all KCET questions
app.get("/api/kcet_dataset", async (req, res) => {
  try {
    const questions = await KcetModel.find().lean();

    if (!questions || questions.length === 0) {
      throw new Error("No data found in MongoDB, using local fallback.");
    }

    res.json(questions);
  } catch (err) {
    console.warn("⚠️ Failed to fetch from MongoDB Atlas, falling back to local JSON:", err.message);

    try {
      if (!fs.existsSync(localFilePath)) {
        throw new Error(`Local JSON file not found at: ${localFilePath}`);
      }

      const data = JSON.parse(fs.readFileSync(localFilePath, "utf8"));

      if (!Array.isArray(data) || data.length === 0) {
        throw new Error("Local JSON is empty or invalid array format.");
      }

      res.json(data);
    } catch (fsErr) {
      console.error("❌ Failed to read or parse local JSON:", fsErr.message);
      res.status(500).json({
        message: "Error fetching KCET data from MongoDB and local JSON fallback failed.",
        error: fsErr.message,
      });
    }
  }
});

// ✅ Route: Import KCET data from local JSON into MongoDB Atlas
app.post("/api/import-kcet", async (req, res) => {
  try {
    const data = JSON.parse(fs.readFileSync(localFilePath, "utf8"));

    if (!Array.isArray(data)) {
      return res.status(400).json({ message: "Invalid JSON format. Expected an array." });
    }

    await KcetModel.deleteMany({});
    await KcetModel.insertMany(data);

    res.json({
      message: `✅ Successfully imported ${data.length} KCET questions into MongoDB Atlas.`,
    });
  } catch (err) {
    console.error("❌ Error importing KCET data:", err.message);
    res.status(500).json({ message: "Error importing KCET data", error: err.message });
  }
});

// ✅ Default route
app.get("/", (req, res) => {
  res.send("🚀 AI Career Roadmap API is running! MongoDB + Local JSON fallback.");
});

// ✅ Start server
const PORT = process.env.PORT || 5000;
app.listen(PORT, () =>
  console.log(`🚀 Server running on port ${PORT}`)
);
