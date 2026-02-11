import { Response, NextFunction } from "express";
import { AuthRequest } from "../middleware/auth";
import User from "../models/User";
import RewardHistory from "../models/RewardHistory";
import RewardTransaction from "../models/RewardTransaction";
import CustodialWallet from "../models/CustodialWallet";
import {
  getBalanceOnChain,
  getUserStatsOnChain,
  redeemOnChain,
  generateRedemptionId,
  isBlockchainConfigured,
  getCurrentChainId,
} from "../services/blockchainServiceV2";

// GET /rewards/balance - Get user's reward balance
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

    // Get custodial wallet
    const wallet = await CustodialWallet.findOne({ userId });

    // Get on-chain stats if wallet exists and blockchain is configured
    let chainStats = null;
    if (wallet && (await isBlockchainConfigured())) {
      try {
        const stats = await getUserStatsOnChain(wallet.address);
        chainStats = {
          balance: Number(stats.balance),
          totalEarned: Number(stats.totalEarned),
          totalRedeemed: Number(stats.totalRedeemed),
          recordCount: Number(stats.recordCount),
        };
      } catch (err) {
        console.error("Failed to get chain stats:", err);
      }
    }

    return res.status(200).json({
      balance: user.totalRewards,
      chainStats,
      walletAddress: wallet?.address || null,
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

    return res.status(200).json({
      totalRewards: user.totalRewards,
      statsByType,
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
    pointsCost: 100,
    description: "Free coffee at partner cafes",
  },
  discount_10: {
    name: "10% Discount",
    pointsCost: 200,
    description: "10% off at partner stores",
  },
  discount_20: {
    name: "20% Discount",
    pointsCost: 350,
    description: "20% off at partner stores",
  },
  tree_planting: {
    name: "Plant a Tree",
    pointsCost: 500,
    description: "Donate to plant a tree in your name",
  },
  eco_kit: {
    name: "Eco Starter Kit",
    pointsCost: 1000,
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

    const options = Object.entries(REDEMPTION_OPTIONS).map(([key, option]) => ({
      id: key,
      ...option,
      canAfford: user.totalRewards >= option.pointsCost,
    }));

    return res.status(200).json({
      currentBalance: user.totalRewards,
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

    // Check user has enough points
    if (user.totalRewards < pointsToRedeem) {
      return res.status(400).json({
        message: "Insufficient points",
        required: pointsToRedeem,
        available: user.totalRewards,
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

    // Deduct points immediately (off-chain, for UX)
    user.totalRewards -= pointsToRedeem;
    await user.save();

    // Record in reward history
    await RewardHistory.create({
      userId,
      type: "redemption",
      points: -pointsToRedeem,
      description: `Redeemed: ${option?.name || rewardType}`,
      referenceId: rewardTx._id,
    });

    // Attempt on-chain redemption
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
        // Note: Points already deducted off-chain
        // Could add reconciliation logic here
      }
      await rewardTx.save();
    }

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
      newBalance: user.totalRewards,
    });
  } catch (error) {
    return next(error);
  }
};
