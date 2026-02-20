import { Router } from "express";
import { recycleWaste, getRecyclingLogs } from "../controllers/recycleController";
import { authMiddleware } from "../middleware/auth";
import { apiLimiter } from "../middleware/rateLimit";
import { validate, recycleSchema } from "../validators/schemas";

const router = Router();

// All routes are protected + rate-limited
router.use(authMiddleware);
router.use(apiLimiter);

// POST /recycle - Log recycling activity
router.post("/", validate(recycleSchema), recycleWaste);

// GET /recycle/logs - Get recycling logs
router.get("/logs", getRecyclingLogs);

export default router;
