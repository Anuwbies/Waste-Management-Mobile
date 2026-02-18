import { Response, NextFunction } from "express";
import { AuthRequest } from "../middleware/auth";
import { ensureCustodialWallet } from "../services/walletService";
import User from "../models/User";

// =========================================================================
// POST /wallet/ensure   –  idempotent wallet provisioning
// =========================================================================
export const ensureWallet = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = req.userId;
    if (!userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    const { address, isNew } = await ensureCustodialWallet(userId);

    return res.status(200).json({
      message: isNew ? "Wallet created successfully" : "Wallet already exists",
      walletAddress: address,
      isNew,
    });
  } catch (error) {
    // Log the full error for server-side debugging while returning a
    // safe message to the client.
    console.error("[walletController] ensureWallet failed:", error);
    return res.status(500).json({
      message: "Wallet creation failed. Please try again later.",
    });
  }
};
