import { Router } from "express";
import {
  register,
  login,
  googleLogin,
  getCurrentUser,
  updateCurrentUser,
} from "../controllers/authController";
import { authMiddleware } from "../middleware/auth";

const router = Router();

// Public routes
router.post("/register", register);
router.post("/login", login);
router.post("/google", googleLogin);

// Protected routes
router.get("/me", authMiddleware, getCurrentUser);
router.put("/me", authMiddleware, updateCurrentUser);

export default router;
