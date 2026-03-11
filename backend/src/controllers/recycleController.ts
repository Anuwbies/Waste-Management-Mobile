import { Response, NextFunction } from "express";
import { AuthRequest } from "../middleware/auth";
import User from "../models/User";
import RecyclingLog from "../models/RecyclingLog";
import RewardHistory from "../models/RewardHistory";
import RecyclingEvent from "../models/RecyclingEvent";
import RewardTransaction from "../models/RewardTransaction";
import CustodialWallet from "../models/CustodialWallet";
import {
  generateEventHash,
  mapWasteTypeToEnum,
  recordRecyclingOnChain,
  isEventUsedOnChain,
  generateDeterministicAddress,
  getCurrentChainId,
  isBlockchainConfigured,
  computeImageHash,
} from "../services/blockchainServiceV2";
import { calculateRewardPoints } from "../services/rewardService";
import { CNN_CONFIDENCE_THRESHOLD } from "../config/env";
import { recordAuditEvent } from "../services/adminAuditService";

/**
 * Get or create custodial wallet for user
 */
const getOrCreateUserWallet = async (userId: string): Promise<string> => {
  // Check if user already has a wallet
  let wallet = await CustodialWallet.findOne({ userId });

  if (wallet) {
    return wallet.address;
  }

  // Create deterministic address (simple approach without HD wallet)
  const address = generateDeterministicAddress(userId);

  // Get next derivation index (for when HD wallet is configured)
  const lastWallet = await CustodialWallet.findOne().sort({ derivationIndex: -1 });
  const nextIndex = lastWallet ? lastWallet.derivationIndex + 1 : 0;

  wallet = await CustodialWallet.create({
    userId,
    address,
    derivationIndex: nextIndex,
  });

  // Update user's wallet address
  await User.findByIdAndUpdate(userId, { walletAddress: address });

  return wallet.address;
};

// POST /recycle - Log recycling activity with idempotency
export const recycleWaste = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const { wasteType, quantity, imageData, metadata } = req.body as {
      wasteType?: string;
      quantity?: number;
      imageData?: string; // Base64 encoded image
      metadata?: {
        deviceId?: string;
        location?: { lat: number; lng: number };
      };
    };

    if (!wasteType) {
      return res.status(400).json({
        message: "wasteType is required",
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const qty = quantity || 1;
    const timestamp = Date.now();

    // ── Confidence gating (source of truth) ──────────────────────────
    // metadata.confidence is sent by the mobile client from the CNN step.
    // If confidence is below the threshold, DENY the reward — no blockchain
    // call, no points, no reward-history entry.
    const confidence: number | undefined =
      (req.body as any).metadata?.confidence != null
        ? Number((req.body as any).metadata.confidence)
        : undefined;

    const isDenied =
      confidence !== undefined && confidence < CNN_CONFIDENCE_THRESHOLD;

    const rewardPoints = isDenied
      ? 0
      : calculateRewardPoints(wasteType) * qty;

    // Compute image hash if provided
    let imageHash: string | undefined;
    if (imageData) {
      const imageBuffer = Buffer.from(imageData, "base64");
      imageHash = computeImageHash(imageBuffer);
    }

    // ── Duplicate image anti-cheat ──────────────────────────────────
    // If the same user has already submitted the exact same image
    // (confirmed or pending), deny the reward immediately.
    if (imageHash) {
      const duplicateEvent = await RecyclingEvent.findOne({
        userId,
        imageHash,
        status: { $in: ["confirmed", "pending"] },
      });

      if (duplicateEvent) {
        console.log(
          `[recycleController] DUPLICATE IMAGE: userId=${userId} imageHash=${imageHash} ` +
            `existing eventId=${duplicateEvent._id}`
        );
        return res.status(409).json({
          message:
            "This image has already been submitted for rewards. Please use a new photo.",
          status: "denied",
          reason: "Duplicate image",
          rewardPoints: 0,
          existingEvent: {
            id: duplicateEvent._id,
            wasteType: duplicateEvent.wasteType,
            rewardPoints: duplicateEvent.rewardPoints,
            status: duplicateEvent.status,
            createdAt: duplicateEvent.createdAt,
          },
        });
      }
    }

    // Generate unique event hash for idempotency
    const eventHash = generateEventHash(
      userId!,
      wasteType,
      timestamp,
      imageHash
    );

    // Check for duplicate in database
    const existingEvent = await RecyclingEvent.findOne({ eventHash });
    if (existingEvent) {
      if (existingEvent.status === "confirmed") {
        return res.status(409).json({
          message: "This recycling event has already been recorded",
          eventHash,
          existingLog: {
            id: existingEvent._id,
            wasteType: existingEvent.wasteType,
            rewardPoints: existingEvent.rewardPoints,
            status: existingEvent.status,
          },
        });
      }

      // Return pending event if still processing
      if (existingEvent.status === "pending") {
        return res.status(202).json({
          message: "Recycling event is being processed",
          eventHash,
          log: {
            id: existingEvent._id,
            wasteType: existingEvent.wasteType,
            rewardPoints: existingEvent.rewardPoints,
            status: existingEvent.status,
          },
        });
      }
    }

    // Get or create custodial wallet for user
    const userWallet = await getOrCreateUserWallet(userId!);
    const wasteTypeEnum = mapWasteTypeToEnum(wasteType);
    const chainId = await getCurrentChainId();

    // ── Denied path — lightweight, no blockchain, no reward writes ──
    if (isDenied) {
      console.log(
        `[recycleController] DENIED: confidence=${confidence?.toFixed(3)} < threshold=${CNN_CONFIDENCE_THRESHOLD} (${wasteType})`
      );

      // Still create a log so the user can see the attempt
      const recyclingLog = await RecyclingLog.create({
        userId,
        wasteType,
        quantity: qty,
        rewardPoints: 0,
      });

      // ── Audit Log recording (real-time) ─────────────────────────────
      recordAuditEvent({
        userId: user._id,
        userEmail: user.email,
        userName: user.name,
        walletAddress: user.walletAddress,
        activityType: "recycle",
        status: "failed",
        wasteType,
        confidence,
        imageHash,
        points: 0,
        recyclingLogId: recyclingLog._id,
      }).catch((err) => console.error("[recycleController] Audit log failed (denied):", err));

      return res.status(200).json({
        message:
          "Classification confidence too low — reward denied. Try a clearer photo.",
        status: "denied",
        reason: "Low confidence",
        confidence,
        log: {
          id: recyclingLog._id,
          wasteType,
          quantity: qty,
          rewardPoints: 0,
          status: "denied",
        },
        totalRewards: user.totalRewards,
      });
    }

    // ── Approved path — full blockchain + reward flow ─────────────────

    // Create recycling event (pending status)
    const recyclingEvent = await RecyclingEvent.create({
      eventHash,
      userId,
      userWallet,
      wasteType,
      imageHash,
      rewardPoints,
      aiConfidence: confidence,
      status: "pending",
      chainId,
      metadata: {
        ...metadata,
        scanTimestamp: new Date(timestamp),
      },
    });

    // Create legacy recycling log for backward compatibility
    const recyclingLog = await RecyclingLog.create({
      userId,
      wasteType,
      quantity: qty,
      rewardPoints,
    });

    // Create reward transaction (pending on-chain confirmation)
    const rewardTx = await RewardTransaction.create({
      userId,
      type: "earn",
      points: rewardPoints,
      eventHash,
      status: "pending",
      chainId,
      description: `Earned ${rewardPoints} points for recycling ${wasteType}`,
    });

    // ── On-chain recording — chain is the SOURCE OF TRUTH ────────────
    // We do NOT increment Mongo user.totalRewards before the chain call
    // succeeds.  This prevents Mongo-tampering from inflating balances.
    const blockchainConfigured = await isBlockchainConfigured();
    let chainSuccess = false;

    if (blockchainConfigured) {
      // Check if already used on-chain (extra safety)
      const usedOnChain = await isEventUsedOnChain(eventHash);
      if (usedOnChain) {
        recyclingEvent.status = "duplicate";
        await recyclingEvent.save();

        return res.status(409).json({
          message: "Event already recorded on blockchain",
          eventHash,
        });
      }

      // Record on blockchain
      const result = await recordRecyclingOnChain(
        eventHash,
        userWallet,
        rewardPoints,
        wasteTypeEnum
      );

      if (result.success) {
        chainSuccess = true;
        recyclingEvent.status = "confirmed";
        recyclingEvent.txHash = result.txHash;
        recyclingEvent.confirmedAt = new Date();
        await recyclingEvent.save();

        recyclingLog.txHash = result.txHash;
        await recyclingLog.save();

        rewardTx.status = "confirmed";
        rewardTx.txHash = result.txHash;
        rewardTx.confirmedAt = new Date();
        await rewardTx.save();

        // Update Mongo cache ONLY after chain success (best-effort cache)
        user.totalRewards += rewardPoints;
        await user.save();

        // Record in reward history
        await RewardHistory.create({
          userId,
          type: "recycling",
          points: rewardPoints,
          description: `Recycled ${qty} ${wasteType} item(s)`,
          referenceId: recyclingLog._id,
        });
      } else {
        recyclingEvent.status = "failed";
        recyclingEvent.errorMessage = result.error;
        recyclingEvent.retryCount += 1;
        await recyclingEvent.save();

        rewardTx.status = "failed";
        rewardTx.errorMessage = result.error;
        await rewardTx.save();

        // DO NOT update Mongo balance — chain failed, no reward granted
        console.error(
          `[recycleController] ON-CHAIN FAILED: ${result.error} (${wasteType}, ${rewardPoints} pts)`
        );
      }
    } else {
      // Blockchain not configured — skip chain, still grant off-chain
      // (dev / fallback mode)
      chainSuccess = true;
      user.totalRewards += rewardPoints;
      await user.save();

      await RewardHistory.create({
        userId,
        type: "recycling",
        points: rewardPoints,
        description: `Recycled ${qty} ${wasteType} item(s)`,
        referenceId: recyclingLog._id,
      });
    }

    console.log(
      `[recycleController] ${chainSuccess ? "APPROVED" : "CHAIN_FAILED"}: ` +
        `confidence=${confidence?.toFixed(3)} wasteType=${wasteType} points=${rewardPoints}`
    );

    // ── Audit Log recording (real-time) ─────────────────────────────
    recordAuditEvent({
      userId: user._id,
      userEmail: user.email,
      userName: user.name,
      walletAddress: userWallet,
      activityType: "recycle",
      status: chainSuccess ? "confirmed" : "failed",
      wasteType,
      confidence,
      imageHash,
      points: rewardPoints,
      txHash: recyclingEvent.txHash,
      chainId,
      eventHash,
      txStatus: chainSuccess ? "success" : "failed",
      recyclingEventId: recyclingEvent._id,
      recyclingLogId: recyclingLog._id,
      rewardTransactionId: rewardTx._id,
    }).catch((err) => console.error("[recycleController] Audit log failed:", err));

    return res.status(chainSuccess ? 200 : 502).json({
      message: chainSuccess
        ? "Recycling activity recorded"
        : "On-chain recording failed. Reward was NOT granted. Please try again.",
      status: chainSuccess ? "approved" : "failed",
      confidence,
      log: {
        id: recyclingLog._id,
        eventId: recyclingEvent._id,
        eventHash,
        wasteType,
        quantity: qty,
        rewardPoints: chainSuccess ? rewardPoints : 0,
        txHash: recyclingEvent.txHash,
        status: recyclingEvent.status,
        chainId: blockchainConfigured ? chainId : null,
      },
      totalRewards: user.totalRewards,
      wallet: userWallet,
    });
  } catch (error) {
    return next(error);
  }
};

// GET /recycle/logs - Get user's recycling logs
// Supports optional ?wasteType=plastic query param for server-side filtering
export const getRecyclingLogs = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const skip = (page - 1) * limit;
    const wasteType = req.query.wasteType as string | undefined;

    // Build filter
    const filter: Record<string, unknown> = { userId };
    if (wasteType) {
      // Case-insensitive match
      filter.wasteType = { $regex: new RegExp(`^${wasteType}$`, "i") };
    }

    const [logs, total] = await Promise.all([
      RecyclingLog.find(filter)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      RecyclingLog.countDocuments(filter),
    ]);

    return res.status(200).json({
      logs,
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

/**
 * DELETE /recycle/logs/:id
 * Delete a recycling log record. Only allowed for the owner.
 */
export const deleteRecyclingLog = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const { id } = req.params;

    const log = await RecyclingLog.findOne({
      _id: id,
      userId,
    });

    if (!log) {
      return res.status(404).json({ message: "Recycling log not found" });
    }

    await RecyclingLog.deleteOne({ _id: id });

    return res.status(200).json({ message: "Recycling log deleted successfully" });
  } catch (error) {
    return next(error);
  }
};
