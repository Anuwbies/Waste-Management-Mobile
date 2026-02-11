import { Router } from "express";
import { recycleWaste, getRecyclingLogs } from "../controllers/recycleController";
import { authMiddleware } from "../middleware/auth";

const router = Router();

// All routes are protected
router.use(authMiddleware);

// POST /recycle - Log recycling activity
router.post("/", recycleWaste);

// GET /recycle/logs - Get recycling logs
router.get("/logs", getRecyclingLogs);

export default router;
