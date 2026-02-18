import { Router } from "express";
import {
  register,
  login,
  googleLogin,
  getCurrentUser,
  updateCurrentUser,
  forgotPassword,
  verifyOtp,
  resetPassword,
  logout,
} from "../controllers/authController";
import { authMiddleware } from "../middleware/auth";
import {
  loginLimiter,
  forgotPasswordLimiter,
  otpVerifyLimiter,
  authGeneralLimiter,
} from "../middleware/rateLimit";

const router = Router();

// Public routes
router.post("/register", authGeneralLimiter, register);
router.post("/login", loginLimiter, login);
router.post("/google", authGeneralLimiter, googleLogin);

// Forgot-password / OTP flow
router.post("/forgot-password", forgotPasswordLimiter, forgotPassword);
router.post("/verify-otp", otpVerifyLimiter, verifyOtp);
router.post("/reset-password", otpVerifyLimiter, resetPassword);

// Protected routes
router.get("/me", authMiddleware, getCurrentUser);
router.put("/me", authMiddleware, updateCurrentUser);
router.post("/logout", authMiddleware, logout);

export default router;
