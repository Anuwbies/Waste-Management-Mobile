import { Response, NextFunction } from "express";
import { AuthRequest } from "../middleware/auth";
import User from "../models/User";
import RewardHistory from "../models/RewardHistory";
import RewardTransaction from "../models/RewardTransaction";
import CustodialWallet from "../models/CustodialWallet";
import {
  getBalanceOnChain,
  getUserStatsOnChain,
  getGlobalStatsOnChain,
  redeemOnChain,
  generateRedemptionId,
  isBlockchainConfigured,
  getCurrentChainId,
} from "../services/blockchainServiceV2";
import { recordAuditEvent } from "../services/adminAuditService";

// ---------------------------------------------------------------------------
// Helper: read the authoritative on-chain balance for a user.
// Falls back to the (deprecated) Mongo cache when the chain is unreachable.
// ---------------------------------------------------------------------------
interface AuthoritativeBalance {
  /** The balance the rest of the endpoint should treat as canonical. */
  balance: number;
  totalEarned: number;
  totalRedeemed: number;
  recordCount: number;
  source: "chain" | "cache";
  walletAddress: string | null;
  integrityWarning?: string;
}

async function getAuthoritativeBalance(
  userId: string,
  mongoBalance: number,
): Promise<AuthoritativeBalance> {
  const wallet = await CustodialWallet.findOne({ userId });
  const walletAddress = wallet?.address ?? null;

  if (walletAddress && (await isBlockchainConfigured())) {
    try {
      const stats = await getUserStatsOnChain(walletAddress);
      const chainBalance = Number(stats.balance);

      // Integrity check: warn if Mongo cache drifted
      let integrityWarning: string | undefined;
      if (mongoBalance !== chainBalance) {
        console.warn(
          `[rewards] INTEGRITY DRIFT userId=${userId} ` +
            `mongo=${mongoBalance} chain=${chainBalance} — preferring chain`,
        );
        integrityWarning =
          `Off-chain cache (${mongoBalance}) differs from on-chain balance (${chainBalance}). Chain is authoritative.`;
      }

      return {
        balance: chainBalance,
        totalEarned: Number(stats.totalEarned),
        totalRedeemed: Number(stats.totalRedeemed),
        recordCount: Number(stats.recordCount),
        source: "chain",
        walletAddress,
        integrityWarning,
      };
    } catch (err) {
      console.error("[rewards] Chain read failed, falling back to Mongo cache:", err);
    }
  }

  // Fallback — no wallet yet or chain unreachable
  return {
    balance: mongoBalance,
    totalEarned: mongoBalance, // best-effort approximation
    totalRedeemed: 0,
    recordCount: 0,
    source: "cache",
    walletAddress,
  };
}

// GET /rewards/balance - Get user's reward balance
// Blockchain is the SOURCE OF TRUTH.  Mongo `user.totalRewards` is only a
// stale cache kept for backward-compat / offline resilience.
export const getRewardBalance = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const auth = await getAuthoritativeBalance(userId!, user.totalRewards);

    return res.status(200).json({
      // Primary — always from chain when available
      balance: auth.balance,
      totalEarned: auth.totalEarned,
      totalRedeemed: auth.totalRedeemed,
      recordCount: auth.recordCount,
      walletAddress: auth.walletAddress,
      source: auth.source,
      // Deprecated — kept for old clients
      chainStats: {
        balance: auth.balance,
        totalEarned: auth.totalEarned,
        totalRedeemed: auth.totalRedeemed,
        recordCount: auth.recordCount,
      },
      ...(auth.integrityWarning ? { integrityWarning: auth.integrityWarning } : {}),
    });
  } catch (error) {
    return next(error);
  }
};

// GET /rewards/history - Get user's reward history
export const getRewardHistory = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const type = req.query.type as string;
    const skip = (page - 1) * limit;

    const query: Record<string, unknown> = { userId };
    if (type && ["recycling", "classification", "bonus", "redemption"].includes(type)) {
      query.type = type;
    }

    const [history, total] = await Promise.all([
      RewardHistory.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      RewardHistory.countDocuments(query),
    ]);

    return res.status(200).json({
      history,
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

// GET /rewards/stats - Get user's reward statistics
// Chain is authoritative for totalRewards; Mongo aggregation for breakdown.
export const getRewardStats = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // On-chain authoritative balance
    const auth = await getAuthoritativeBalance(userId!, user.totalRewards);

    // Off-chain breakdown (RewardHistory is append-only and trustworthy for
    // per-type breakdowns, but the *total* comes from chain).
    const stats = await RewardHistory.aggregate([
      { $match: { userId: user._id } },
      {
        $group: {
          _id: "$type",
          totalPoints: { $sum: "$points" },
          count: { $sum: 1 },
        },
      },
    ]);

    const statsByType = stats.reduce(
      (acc, stat) => {
        acc[stat._id] = {
          totalPoints: stat.totalPoints,
          count: stat.count,
        };
        return acc;
      },
      {} as Record<string, { totalPoints: number; count: number }>
    );

    // Global on-chain stats
    let globalStats = null;
    if (await isBlockchainConfigured()) {
      try {
        const g = await getGlobalStatsOnChain();
        globalStats = {
          totalEvents: Number(g.totalEvents),
          totalMinted: Number(g.totalMinted),
          totalBurned: Number(g.totalBurned),
        };
      } catch { /* non-critical */ }
    }

    return res.status(200).json({
      totalRewards: auth.balance,
      totalEarned: auth.totalEarned,
      totalRedeemed: auth.totalRedeemed,
      recordCount: auth.recordCount,
      source: auth.source,
      statsByType,
      globalStats,
      ...(auth.integrityWarning ? { integrityWarning: auth.integrityWarning } : {}),
    });
  } catch (error) {
    return next(error);
  }
};

// Redemption options configuration
const REDEMPTION_OPTIONS: Record<
  string,
  { name: string; pointsCost: number; description: string }
> = {
  coffee_voucher: {
    name: "Coffee Voucher",
    pointsCost: 1,
    description: "Free coffee at partner cafes",
  },
  discount_10: {
    name: "10% Discount",
    pointsCost: 20,
    description: "10% off at partner stores",
  },
  discount_20: {
    name: "20% Discount",
    pointsCost: 35,
    description: "20% off at partner stores",
  },
  tree_planting: {
    name: "Plant a Tree",
    pointsCost: 50,
    description: "Donate to plant a tree in your name",
  },
  eco_kit: {
    name: "Eco Starter Kit",
    pointsCost: 100,
    description: "Reusable bags, bottles, and utensils",
  },
};

// GET /rewards/options - Get available redemption options
export const getRedemptionOptions = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const user = await User.findById(userId);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Use on-chain balance for affordability check
    const auth = await getAuthoritativeBalance(userId!, user.totalRewards);

    const options = Object.entries(REDEMPTION_OPTIONS).map(([key, option]) => ({
      id: key,
      ...option,
      canAfford: auth.balance >= option.pointsCost,
    }));

    return res.status(200).json({
      currentBalance: auth.balance,
      source: auth.source,
      options,
    });
  } catch (error) {
    return next(error);
  }
};

// POST /rewards/redeem - Redeem points for rewards
export const redeemRewards = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const { rewardType, customPoints } = req.body as {
      rewardType: string;
      customPoints?: number;
    };

    if (!rewardType) {
      return res.status(400).json({ message: "rewardType is required" });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Get redemption cost
    const option = REDEMPTION_OPTIONS[rewardType];
    const pointsToRedeem = customPoints ?? option?.pointsCost;

    if (!pointsToRedeem || pointsToRedeem <= 0) {
      return res.status(400).json({ message: "Invalid redemption option" });
    }

    // Check user has enough points — chain is authoritative
    const auth = await getAuthoritativeBalance(userId!, user.totalRewards);
    if (auth.balance < pointsToRedeem) {
      return res.status(400).json({
        message: "Insufficient points",
        required: pointsToRedeem,
        available: auth.balance,
        source: auth.source,
      });
    }

    // Get user wallet
    const wallet = await CustodialWallet.findOne({ userId });
    if (!wallet) {
      return res.status(400).json({
        message: "No wallet found. Please record a recycling activity first.",
      });
    }

    const timestamp = Date.now();
    const redemptionId = generateRedemptionId(userId!, rewardType, timestamp);
    const chainId = await getCurrentChainId();

    // Create reward transaction (pending)
    const rewardTx = await RewardTransaction.create({
      userId,
      type: "redeem",
      points: -pointsToRedeem, // Negative for deductions
      redemptionId,
      rewardType,
      status: "pending",
      chainId,
      description: option?.name || `Redeemed ${pointsToRedeem} points`,
    });

    // Attempt on-chain redemption FIRST — chain is the authority.
    // Only update Mongo cache after the chain call succeeds.
    let txHash: string | undefined;
    const blockchainConfigured = await isBlockchainConfigured();

    if (blockchainConfigured) {
      const result = await redeemOnChain(
        wallet.address,
        pointsToRedeem,
        rewardType,
        redemptionId
      );

      if (result.success) {
        txHash = result.txHash;
        rewardTx.status = "confirmed";
        rewardTx.txHash = txHash;
        rewardTx.confirmedAt = new Date();
      } else {
        rewardTx.status = "failed";
        rewardTx.errorMessage = result.error;
        await rewardTx.save();

        return res.status(500).json({
          message: "On-chain redemption failed. Points were NOT deducted.",
          error: result.error,
        });
      }
      await rewardTx.save();
    }

    // Update Mongo cache (best-effort, chain is truth)
    user.totalRewards = Math.max(0, user.totalRewards - pointsToRedeem);
    await user.save();

    // Record in reward history
    await RewardHistory.create({
      userId,
      type: "redemption",
      points: -pointsToRedeem,
      description: `Redeemed: ${option?.name || rewardType}`,
      referenceId: rewardTx._id,
    });

    // Re-read authoritative balance after redemption
    const postAuth = await getAuthoritativeBalance(userId!, user.totalRewards);

    // ── Audit Log recording (real-time) ─────────────────────────────
    recordAuditEvent({
      userId: user._id,
      userEmail: user.email,
      userName: user.name,
      walletAddress: wallet.address,
      activityType: "redeem",
      status: rewardTx.status === "confirmed" ? "confirmed" : "pending",
      points: -pointsToRedeem,
      txHash: rewardTx.txHash,
      chainId,
      txStatus: rewardTx.status === "confirmed" ? "success" : "pending",
      rewardTransactionId: rewardTx._id,
      metadata: {
        rewardType,
        rewardName: option?.name || rewardType,
        redemptionId,
      },
    }).catch((err) => console.error("[rewardsController] Audit log failed:", err));

    return res.status(200).json({
      message: "Redemption successful",
      redemption: {
        id: rewardTx._id,
        redemptionId,
        rewardType,
        rewardName: option?.name || rewardType,
        pointsRedeemed: pointsToRedeem,
        txHash,
        status: rewardTx.status,
      },
      newBalance: postAuth.balance,
      source: postAuth.source,
    });
  } catch (error) {
    return next(error);
  }
};

/**
 * DELETE /rewards/history/:id
 * Delete a reward transaction record. Only allowed for the owner.
 */
export const deleteRewardTransaction = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;
    const { id } = req.params;

    const tx = await RewardTransaction.findOne({
      _id: id,
      userId,
    });

    if (!tx) {
      return res.status(404).json({ message: "Reward transaction not found" });
    }

    await RewardTransaction.deleteOne({ _id: id });

    return res.status(200).json({ message: "Reward transaction deleted successfully" });
  } catch (error) {
    return next(error);
  }
};
