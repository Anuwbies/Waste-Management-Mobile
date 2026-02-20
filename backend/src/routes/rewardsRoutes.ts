import { Router } from "express";
import { authMiddleware } from "../middleware/auth";
import { apiLimiter } from "../middleware/rateLimit";
import { validate, redeemSchema } from "../validators/schemas";
import {
  getRewardBalance,
  getRewardHistory,
  getRewardStats,
  getRedemptionOptions,
  redeemRewards,
} from "../controllers/rewardsController";

const router = Router();

// All routes are protected + rate-limited
router.use(authMiddleware);
router.use(apiLimiter);

// GET /rewards/balance - Get user's reward balance
router.get("/balance", getRewardBalance);

// GET /rewards/history - Get user's reward history
router.get("/history", getRewardHistory);

// GET /rewards/stats - Get user's reward statistics
router.get("/stats", getRewardStats);

// GET /rewards/options - Get available redemption options
router.get("/options", getRedemptionOptions);

// POST /rewards/redeem - Redeem points for rewards
router.post("/redeem", validate(redeemSchema), redeemRewards);

export default router;
