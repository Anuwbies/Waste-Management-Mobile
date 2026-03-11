import { Response, NextFunction } from "express";
import path from "path";
import fs from "fs";
import { AuthRequest } from "../middleware/auth";
import WasteClassification from "../models/WasteClassification";
import User from "../models/User";
import { calculateRewardPoints } from "../services/rewardService";
import { classifyImage, AiClassificationResult } from "../services/aiService";
import { generateDisposalGuide, isValidWasteType } from "../services/llmService";
import { CNN_CONFIDENCE_THRESHOLD } from "../config/env";
import { computeImageHash } from "../services/blockchainServiceV2";
import { recordAuditEvent } from "../services/adminAuditService";

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, "..", "..", "uploads");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

// Use centralised threshold from env.ts (default 0.80)
const REWARD_CONFIDENCE_THRESHOLD = CNN_CONFIDENCE_THRESHOLD;

// Canonical waste types that qualify for rewards
const REWARDABLE_TYPES = new Set([
  "plastic",
  "paper",
  "metal",
  "glass",
  "organic",
  "e-waste",
]);

/**
 * Classify an image using the AI inference service.
 * Falls back to an error if the service is unreachable.
 */
const classifyWasteImage = async (
  imagePath: string
): Promise<AiClassificationResult> => {
  return classifyImage(imagePath);
};

// POST /waste/upload - Upload and classify waste image
export const uploadWasteImage = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;

    if (!req.file) {
      return res.status(400).json({ message: "No image file uploaded" });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Get file path
    const imageUrl = `/uploads/${req.file.filename}`;

    // ── Compute image hash & duplicate check ─────────────────────────
    const imageBuffer = fs.readFileSync(req.file.path);
    const imageHash = computeImageHash(imageBuffer);

    // If this user has already uploaded the exact same image
    // and it was approved, deny the duplicate.
    const duplicateClassification = await WasteClassification.findOne({
      userId,
      imageHash,
      status: { $in: ["approved", "pending"] },
    });

    if (duplicateClassification) {
      // Clean up the newly-uploaded file since we are rejecting it
      try {
        fs.unlinkSync(req.file.path);
      } catch {
        /* ignore cleanup errors */
      }

      console.log(
        `[wasteController] DUPLICATE IMAGE: userId=${userId} imageHash=${imageHash} ` +
          `existing classificationId=${duplicateClassification._id}`
      );

      return res.status(409).json({
        message:
          "This image has already been submitted. Please take a new photo.",
        status: "denied",
        reason: "Duplicate image",
        existingClassification: {
          id: duplicateClassification._id,
          wasteType: duplicateClassification.wasteType,
          confidence: duplicateClassification.confidence,
          rewardPoints: duplicateClassification.rewardPoints,
          createdAt: duplicateClassification.createdAt,
        },
      });
    }

    // Classify the waste via AI inference service
    let classification: AiClassificationResult;
    try {
      classification = await classifyWasteImage(req.file.path);
    } catch (aiError) {
      console.error("[wasteController] AI service error:", aiError);
      return res.status(503).json({
        message: "AI classification service is unavailable. Please try again later.",
        error: (aiError as Error).message,
      });
    }

    const { wasteType, confidence, topK, rawLabel, modelVersion } = classification;

    // Determine if reward qualifies
    const isDenied =
      !REWARDABLE_TYPES.has(wasteType) ||
      wasteType === "unknown" ||
      confidence < REWARD_CONFIDENCE_THRESHOLD;

    const rewardPoints = isDenied ? 0 : calculateRewardPoints(wasteType);
    // Use "pending" — reward is NOT granted yet; only POST /recycle grants rewards.
    const status = isDenied ? "denied" : "pending";

    // Save classification record
    const wasteRecord = await WasteClassification.create({
      userId,
      imageUrl,
      imageHash,
      wasteType,
      confidence,
      rewardPoints,
      rawLabel,
      modelVersion,
      status,
    });

    // ── Audit Log recording (real-time) ─────────────────────────────
    // Off-load to audit trail so admin can see scans in the web dashboard.
    recordAuditEvent({
      userId: user._id,
      userEmail: user.email,
      userName: user.name,
      walletAddress: user.walletAddress,
      activityType: "scan",
      status: status === "denied" ? "failed" : "pending",
      wasteType,
      confidence,
      rawLabel,
      modelVersion,
      imageUrl,
      imageHash,
      points: rewardPoints,
      classificationId: wasteRecord._id,
    }).catch((err) => console.error("[wasteController] Audit log failed:", err));

    // NOTE: Rewards are NOT granted here. The user only sees "potential"
    // points at this stage. Actual reward granting happens in POST /recycle
    // after the user explicitly submits for rewards.

    console.log(
      `[wasteController] Classification: ${wasteType} (${(confidence * 100).toFixed(1)}%) ` +
        `raw="${rawLabel}" status=${status} points=${rewardPoints}`
    );

    return res.status(201).json({
      message:
        isDenied
          ? "Image classified but reward denied (low confidence or unsupported type)"
          : "Image uploaded and classified successfully",
      classification: {
        id: wasteRecord._id,
        imageUrl,
        wasteType,
        confidence,
        rawLabel,
        modelVersion,
        topK,
        rewardPoints,
        status,
      },
      totalRewards: user.totalRewards,
    });
  } catch (error) {
    return next(error);
  }
};

// POST /waste/classify - Classify waste without storing (for preview)
export const classifyWaste = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: "No image file uploaded" });
    }

    // Classify the waste via AI inference service
    let classification: AiClassificationResult;
    try {
      classification = await classifyImage(req.file.path);
    } catch (aiError) {
      // Clean up temp file before returning error
      try { fs.unlinkSync(req.file.path); } catch { /* ignore */ }
      console.error("[wasteController] AI service error:", aiError);
      return res.status(503).json({
        message: "AI classification service is unavailable. Please try again later.",
        error: (aiError as Error).message,
      });
    }

    const { wasteType, confidence, topK, rawLabel, modelVersion } = classification;

    // Calculate potential reward points (0 if denied)
    const isDenied =
      !REWARDABLE_TYPES.has(wasteType) ||
      wasteType === "unknown" ||
      confidence < REWARD_CONFIDENCE_THRESHOLD;

    const rewardPoints = isDenied ? 0 : calculateRewardPoints(wasteType);

    // Delete temporary file
    try { fs.unlinkSync(req.file.path); } catch { /* ignore */ }

    return res.status(200).json({
      wasteType,
      confidence,
      rawLabel,
      modelVersion,
      topK,
      potentialRewardPoints: rewardPoints,
      status: isDenied ? "denied" : "approved",
    });
  } catch (error) {
    return next(error);
  }
};

// GET /waste/history - Get user's classification history
export const getWasteHistory = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const skip = (page - 1) * limit;

    const [classifications, total] = await Promise.all([
      WasteClassification.find({ userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      WasteClassification.countDocuments({ userId }),
    ]);

    return res.status(200).json({
      classifications,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    return next(error);
  }
};

// GET /waste/:id - Get single classification
export const getClassification = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const { id } = req.params;

    const classification = await WasteClassification.findOne({
      _id: id,
      userId,
    }).lean();

    if (!classification) {
      return res.status(404).json({ message: "Classification not found" });
    }

    return res.status(200).json({ classification });
  } catch (error) {
    return next(error);
  }
};

/**
 * DELETE /waste/:id
 * Delete a classification record. Only allowed for the owner.
 */
export const deleteClassification = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const { id } = req.params;

    const classification = await WasteClassification.findOne({
      _id: id,
      userId,
    });

    if (!classification) {
      return res.status(404).json({ message: "Classification not found" });
    }

    await WasteClassification.deleteOne({ _id: id });

    return res.status(200).json({ message: "Classification deleted successfully" });
  } catch (error) {
    return next(error);
  }
};

// POST /waste/suggestion - Get LLM-powered disposal suggestions for a waste type
export const getDisposalSuggestion = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const { wasteType, confidence, topK, rawLabel } = req.body;

    if (!wasteType) {
      return res.status(400).json({ message: "wasteType is required" });
    }

    // Reject unknown waste types before touching the LLM
    const normType = wasteType.toLowerCase().trim();
    if (!isValidWasteType(normType)) {
      return res.status(422).json({
        message: `Unsupported waste type: "${normType}". Accepted: plastic, paper, metal, glass, organic, e-waste.`,
      });
    }

    const guide = await generateDisposalGuide({
      wasteType,
      confidence: typeof confidence === "number" ? confidence : 1.0,
      rawLabel,
      topK,
    });

    return res.status(200).json(guide);
  } catch (error) {
    return next(error);
  }
};
