import { Request, Response, NextFunction } from "express";
import User from "../models/User";
import CustodialWallet from "../models/CustodialWallet";
import { getUserStatsOnChain, isBlockchainConfigured } from "../services/blockchainServiceV2";

export const getUserRewards = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { id } = req.params;
    const user = await User.findById(id);

    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Chain is authoritative
    const wallet = await CustodialWallet.findOne({ userId: id });
    let chainBalance = 0;
    let chainEarned = 0;
    let chainRedeemed = 0;
    let recordCount = 0;
    let source: "chain" | "cache" = "cache";

    if (wallet && (await isBlockchainConfigured())) {
      try {
        const stats = await getUserStatsOnChain(wallet.address);
        chainBalance = Number(stats.balance);
        chainEarned = Number(stats.totalEarned);
        chainRedeemed = Number(stats.totalRedeemed);
        recordCount = Number(stats.recordCount);
        source = "chain";
      } catch {
        // fallback to Mongo
        chainBalance = user.totalRewards;
      }
    } else {
      chainBalance = user.totalRewards;
    }

    return res.status(200).json({
      userId: user.id,
      walletAddress: wallet?.address ?? user.walletAddress,
      balance: chainBalance,
      totalEarned: chainEarned,
      totalRedeemed: chainRedeemed,
      recordCount,
      source,
      // deprecated
      chainRewards: chainBalance,
    });
  } catch (error) {
    return next(error);
  }
};
