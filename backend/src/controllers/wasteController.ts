import { Response, NextFunction } from "express";
import path from "path";
import fs from "fs";
import { AuthRequest } from "../middleware/auth";
import WasteClassification from "../models/WasteClassification";
import User from "../models/User";
import RewardHistory from "../models/RewardHistory";
import { calculateRewardPoints } from "../services/rewardService";
import { classifyImage, AiClassificationResult } from "../services/aiService";
import { CNN_CONFIDENCE_THRESHOLD } from "../config/env";

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
    const status = isDenied ? "denied" : "approved";

    // Save classification record
    const wasteRecord = await WasteClassification.create({
      userId,
      imageUrl,
      wasteType,
      confidence,
      rewardPoints,
      rawLabel,
      modelVersion,
      status,
    });

    // Only update user rewards if approved
    if (!isDenied) {
      user.totalRewards += rewardPoints;
      await user.save();

      // Record in reward history
      await RewardHistory.create({
        userId,
        type: "classification",
        points: rewardPoints,
        description: `Classified ${wasteType} waste (${(confidence * 100).toFixed(0)}% confidence)`,
        referenceId: wasteRecord._id,
      });
    }

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

// Disposal suggestions database (deterministic fallback for LLM)
const disposalSuggestions: Record<
  string,
  {
    binType: string;
    steps: string[];
    warnings: string[];
    tips: string[];
    isRecyclable: boolean;
    impactMessage: string;
  }
> = {
  plastic: {
    binType: "Blue Recycling Bin",
    steps: [
      "Remove any food residue",
      "Rinse the container if possible",
      "Remove caps and lids (recycle separately)",
      "Flatten bottles to save space",
      "Place in blue recycling bin",
    ],
    warnings: [
      "No plastic bags in recycling bin",
      "Styrofoam is not recyclable",
    ],
    tips: [
      "Check the recycling symbol (♻️) for plastic type",
      "Types 1 (PET) and 2 (HDPE) are most recyclable",
    ],
    isRecyclable: true,
    impactMessage:
      "Recycling one plastic bottle saves enough energy to power a lightbulb for 3 hours!",
  },
  paper: {
    binType: "Blue Recycling Bin",
    steps: [
      "Remove any plastic wrapping or tape",
      "Flatten cardboard boxes",
      "Keep paper dry and clean",
      "Place in paper recycling bin",
    ],
    warnings: ["No wet or greasy paper (like pizza boxes)", "No wax-coated paper"],
    tips: [
      "Paper can be recycled 5-7 times",
      "Shredded paper should go in a paper bag",
    ],
    isRecyclable: true,
    impactMessage: "Recycling paper saves 17 trees per ton!",
  },
  metal: {
    binType: "Blue Recycling Bin",
    steps: [
      "Empty and rinse cans",
      "Remove paper labels if possible",
      "Crush cans to save space",
      "Place in metal recycling bin",
    ],
    warnings: [
      "No aerosol cans unless empty",
      "No paint cans (hazardous waste)",
    ],
    tips: [
      "Aluminum can be recycled infinitely",
      "Recycling aluminum uses 95% less energy than new production",
    ],
    isRecyclable: true,
    impactMessage:
      "Recycling one aluminum can saves enough energy to run a TV for 3 hours!",
  },
  glass: {
    binType: "Green Glass Bin",
    steps: [
      "Remove lids and caps",
      "Rinse bottles and jars",
      "Remove any non-glass attachments",
      "Place in glass recycling bin",
    ],
    warnings: [
      "No broken glass in regular recycling",
      "No ceramics, mirrors, or window glass",
    ],
    tips: [
      "Glass can be recycled indefinitely",
      "Color-separate if your area requires it",
    ],
    isRecyclable: true,
    impactMessage: "Recycling glass reduces air pollution by 20% and water pollution by 50%!",
  },
  organic: {
    binType: "Green Compost Bin",
    steps: [
      "Remove any plastic packaging",
      "Place food scraps in compost bin",
      "Include fruit and vegetable peels",
      "Coffee grounds and tea bags are compostable",
    ],
    warnings: [
      "No meat or dairy in home compost",
      "No diseased plants",
    ],
    tips: [
      "Composting reduces methane from landfills",
      "Use compost to enrich garden soil",
    ],
    isRecyclable: false,
    impactMessage:
      "Composting food waste reduces greenhouse gas emissions by up to 50%!",
  },
  "e-waste": {
    binType: "E-Waste Collection Point",
    steps: [
      "Back up any important data",
      "Factory reset devices to protect privacy",
      "Remove batteries if possible (recycle separately)",
      "Take to certified e-waste collection point",
    ],
    warnings: [
      "Never throw electronics in regular trash",
      "Batteries can cause fires in landfills",
      "Contains hazardous materials like lead and mercury",
    ],
    tips: [
      "Many retailers offer free e-waste recycling",
      "Consider donating working devices",
      "Check for manufacturer take-back programs",
    ],
    isRecyclable: true,
    impactMessage:
      "Recycling one million laptops saves energy equivalent to electricity used by 3,500 homes in a year!",
  },
};

// POST /waste/suggestion - Get disposal suggestions for a waste type
export const getDisposalSuggestion = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const { wasteType, confidence, context } = req.body;

    if (!wasteType) {
      return res.status(400).json({ message: "wasteType is required" });
    }

    const normalizedType = wasteType.toLowerCase().trim();

    // Get suggestion from database (fallback/deterministic mode)
    const suggestion = disposalSuggestions[normalizedType];

    if (!suggestion) {
      // Return generic suggestion for unknown waste types
      return res.status(200).json({
        binType: "General Waste Bin",
        steps: [
          "Check local guidelines for this item",
          "If recyclable, clean and dry before disposal",
          "Place in appropriate bin",
        ],
        warnings: ["When in doubt, check with local waste management"],
        tips: ["Consider if the item can be reused or donated"],
        localRules: null,
        isRecyclable: false,
        impactMessage: "Every small action helps protect our environment!",
      });
    }

    // Add confidence-based warnings if provided
    const responseWarnings = [...suggestion.warnings];
    if (confidence && confidence < 0.8) {
      responseWarnings.unshift(
        "Classification confidence is low - please verify the waste type"
      );
    }

    return res.status(200).json({
      binType: suggestion.binType,
      steps: suggestion.steps,
      warnings: responseWarnings,
      tips: suggestion.tips,
      localRules: null, // Can be extended with location-based rules
      isRecyclable: suggestion.isRecyclable,
      impactMessage: suggestion.impactMessage,
    });
  } catch (error) {
    return next(error);
  }
};
