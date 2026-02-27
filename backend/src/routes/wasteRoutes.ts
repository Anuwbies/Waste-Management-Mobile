import { Router } from "express";
import crypto from "crypto";
import multer from "multer";
import path from "path";
import { authMiddleware } from "../middleware/auth";
import { uploadLimiter, apiLimiter, suggestionLimiter } from "../middleware/rateLimit";
import { validate, disposalSuggestionSchema } from "../validators/schemas";
import {
  uploadWasteImage,
  classifyWaste,
  getWasteHistory,
  getClassification,
  getDisposalSuggestion,
} from "../controllers/wasteController";

const router = Router();

// ── Allowed extensions (lowercase, single-dot) ──────────────────────────────
const ALLOWED_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".webp", ".heic"]);

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => {
    cb(null, path.join(__dirname, "..", "..", "uploads"));
  },
  filename: (_req, _file, cb) => {
    // Random filename to prevent path-traversal & name collisions
    const random = crypto.randomBytes(16).toString("hex");
    // We determine extension from MIME inside fileFilter; store as .bin
    // then rename after classification if needed.  For simplicity keep ext.
    const ext = ALLOWED_EXTENSIONS.has(path.extname(_file.originalname).toLowerCase())
      ? path.extname(_file.originalname).toLowerCase()
      : ".bin";
    cb(null, `waste-${random}${ext}`);
  },
});

const fileFilter = (
  _req: Express.Request,
  file: Express.Multer.File,
  cb: multer.FileFilterCallback
) => {
  const allowedMimes = ["image/jpeg", "image/png", "image/webp", "image/heic"];
  const ext = path.extname(file.originalname).toLowerCase();

  // Reject double extensions (e.g. "photo.jpg.exe")
  const dots = file.originalname.split(".").length - 1;
  if (dots > 1) {
    return cb(new Error("Invalid file type. Double extensions are not allowed."));
  }

  if (!allowedMimes.includes(file.mimetype) || !ALLOWED_EXTENSIONS.has(ext)) {
    return cb(new Error("Invalid file type. Only JPEG, PNG, WebP, and HEIC are allowed."));
  }
  cb(null, true);
};

const upload = multer({
  storage,
  fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
    files: 1, // single file only
  },
});

// All routes are protected
router.use(authMiddleware);

// POST /waste/upload - Upload and classify waste image
router.post("/upload", uploadLimiter, upload.single("image"), uploadWasteImage);

// POST /waste/classify - Classify waste without storing (preview)
router.post("/classify", uploadLimiter, upload.single("image"), classifyWaste);

// POST /waste/suggestion - Get disposal suggestions for a waste type
router.post("/suggestion", suggestionLimiter, validate(disposalSuggestionSchema), getDisposalSuggestion);

// GET /waste/history - Get classification history
router.get("/history", apiLimiter, getWasteHistory);

// GET /waste/:id - Get single classification
router.get("/:id", apiLimiter, getClassification);

export default router;
