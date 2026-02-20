import { Router } from "express";
import { getUserRewards } from "../controllers/userController";
import { apiLimiter } from "../middleware/rateLimit";

const router = Router();

// Rate-limit public route
router.get("/:id/rewards", apiLimiter, getUserRewards);

export default router;
