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
    const rewardPoints = calculateRewardPoints(wasteType) * qty;
    const timestamp = Date.now();

    // Compute image hash if provided
    let imageHash: string | undefined;
    if (imageData) {
      const imageBuffer = Buffer.from(imageData, "base64");
      imageHash = computeImageHash(imageBuffer);
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

    // Create recycling event (pending status)
    const recyclingEvent = await RecyclingEvent.create({
      eventHash,
      userId,
      userWallet,
      wasteType,
      imageHash,
      rewardPoints,
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

    // Update user rewards immediately (off-chain, for UX)
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

    // Attempt on-chain recording (async, non-blocking for UX)
    const blockchainConfigured = await isBlockchainConfigured();
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
      } else {
        recyclingEvent.status = "failed";
        recyclingEvent.errorMessage = result.error;
        recyclingEvent.retryCount += 1;
        await recyclingEvent.save();

        rewardTx.status = "failed";
        rewardTx.errorMessage = result.error;
        await rewardTx.save();

        // Note: User still gets off-chain rewards even if on-chain fails
        // A background job can retry failed transactions
      }
    }

    return res.status(200).json({
      message: "Recycling activity recorded",
      log: {
        id: recyclingLog._id,
        eventId: recyclingEvent._id,
        eventHash,
        wasteType,
        quantity: qty,
        rewardPoints,
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
