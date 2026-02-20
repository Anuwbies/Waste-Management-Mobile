import { Router } from "express";
import { ensureWallet } from "../controllers/walletController";
import { authMiddleware } from "../middleware/auth";
import { apiLimiter } from "../middleware/rateLimit";

const router = Router();

// POST /wallet/ensure – idempotent; creates wallet if missing
router.post("/ensure", authMiddleware, apiLimiter, ensureWallet);

export default router;
