import { Request, Response, NextFunction } from "express";
import User from "../models/User";
import { getTotalRewardsOnChain } from "../services/blockchainService";

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

    const chainRewards = await getTotalRewardsOnChain(user.walletAddress);

    return res.status(200).json({
      userId: user.id,
      walletAddress: user.walletAddress,
      chainRewards,
    });
  } catch (error) {
    return next(error);
  }
};
