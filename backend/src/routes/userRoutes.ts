import { Router } from "express";
import { getUserRewards } from "../controllers/userController";

const router = Router();

router.get("/:id/rewards", getUserRewards);

export default router;
