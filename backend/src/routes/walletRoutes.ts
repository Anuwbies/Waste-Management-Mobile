import { Router } from "express";
import { ensureWallet } from "../controllers/walletController";
import { authMiddleware } from "../middleware/auth";

const router = Router();

// POST /wallet/ensure – idempotent; creates wallet if missing
router.post("/ensure", authMiddleware, ensureWallet);

export default router;
