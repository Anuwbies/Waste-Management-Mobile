import { Router } from "express";
import multer from "multer";
import path from "path";
import { authMiddleware } from "../middleware/auth";
import {
  uploadWasteImage,
  classifyWaste,
  getWasteHistory,
  getClassification,
  getDisposalSuggestion,
} from "../controllers/wasteController";

const router = Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, path.join(__dirname, "..", "..", "uploads"));
  },
  filename: (_req, file, cb) => {
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, `waste-${uniqueSuffix}${ext}`);
  },
});

const fileFilter = (
  _req: Express.Request,
  file: Express.Multer.File,
  cb: multer.FileFilterCallback
) => {
  const allowedTypes = ["image/jpeg", "image/png", "image/webp", "image/heic"];
  if (allowedTypes.includes(file.mimetype)) {
    cb(null, true);
  } else {
    cb(new Error("Invalid file type. Only JPEG, PNG, WebP, and HEIC are allowed."));
  }
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
});

// All routes are protected
router.use(authMiddleware);

// POST /waste/upload - Upload and classify waste image
router.post("/upload", upload.single("image"), uploadWasteImage);

// POST /waste/classify - Classify waste without storing (preview)
router.post("/classify", upload.single("image"), classifyWaste);

// POST /waste/suggestion - Get disposal suggestions for a waste type
router.post("/suggestion", getDisposalSuggestion);

// GET /waste/history - Get classification history
router.get("/history", getWasteHistory);

// GET /waste/:id - Get single classification
router.get("/:id", getClassification);

export default router;
