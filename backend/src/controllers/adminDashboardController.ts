/**
 * Admin Dashboard Controller
 * ==========================
 * GET /admin/dashboard
 *
 * Returns the shape the frontend DashboardStats type expects.
 */

import { Response } from "express";
import { AuthRequest } from "../middleware/auth";
import User from "../models/User";
import WasteClassification from "../models/WasteClassification";
import RewardTransaction from "../models/RewardTransaction";
import { getBlockchainHealth } from "../services/blockchainServiceV2";
import { getAiHealth } from "../services/aiService";
import { countToday, sumPointsToday } from "../services/adminAuditService";
import { logger } from "../config/logger";

export const getDashboard = async (req: AuthRequest, res: Response) => {
  try {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);

    // ── Parallel data fetches ──
    const [
      totalUsers,
      totalScansToday,
      approvedScans,
      deniedScans,
      totalPointsMinted,
      blockchainHealth,
      aiHealth,
    ] = await Promise.all([
      User.countDocuments(),
      WasteClassification.countDocuments({ createdAt: { $gte: startOfDay } }),
      WasteClassification.countDocuments({
        createdAt: { $gte: startOfDay },
        status: "approved",
      }),
      WasteClassification.countDocuments({
        createdAt: { $gte: startOfDay },
        status: "denied",
      }),
      sumPointsToday(),
      getBlockchainHealth().catch((e) => {
        logger.warn("Blockchain health check failed:", e);
        return {
          ok: false,
          chainId: 0,
          contractAddress: process.env.CONTRACT_ADDRESS ?? "",
          error: (e as Error).message,
        };
      }),
      getAiHealth().catch((e) => {
        logger.warn("AI health check failed:", e);
        return { status: "offline", modelLoaded: false, modelVersion: "unknown" };
      }),
    ]);

    // ── Response shape matches frontend DashboardStats ──
    return res.json({
      totalUsers,
      totalScansToday,
      approvedScans,
      deniedScans,
      totalPointsMinted,
      blockchain: {
        chainId: (blockchainHealth as Record<string, unknown>).chainId ?? 0,
        contractAddress:
          (blockchainHealth as Record<string, unknown>).contractAddress ??
          process.env.CONTRACT_ADDRESS ??
          "",
        status: (blockchainHealth as Record<string, unknown>).ok
          ? "connected"
          : "disconnected",
      },
      aiService: {
        status: (aiHealth as Record<string, unknown>).modelLoaded
          ? "online"
          : "offline",
        modelVersion:
          ((aiHealth as Record<string, unknown>).modelVersion as string) ??
          undefined,
      },
    });
  } catch (error) {
    logger.error("getDashboard error:", error);
    return res.status(500).json({ message: "Failed to load dashboard data" });
  }
};
