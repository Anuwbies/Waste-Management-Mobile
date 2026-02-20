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
import {
  validate,
  registerSchema,
  loginSchema,
  googleLoginSchema,
  forgotPasswordSchema,
  verifyOtpSchema,
  resetPasswordSchema,
  updateUserSchema,
} from "../validators/schemas";

const router = Router();

// Public routes
router.post("/register", authGeneralLimiter, validate(registerSchema), register);
router.post("/login", loginLimiter, validate(loginSchema), login);
router.post("/google", authGeneralLimiter, validate(googleLoginSchema), googleLogin);

// Forgot-password / OTP flow
router.post("/forgot-password", forgotPasswordLimiter, validate(forgotPasswordSchema), forgotPassword);
router.post("/verify-otp", otpVerifyLimiter, validate(verifyOtpSchema), verifyOtp);
router.post("/reset-password", otpVerifyLimiter, validate(resetPasswordSchema), resetPassword);

// Protected routes
router.get("/me", authMiddleware, getCurrentUser);
router.put("/me", authMiddleware, validate(updateUserSchema), updateCurrentUser);
router.post("/logout", authMiddleware, logout);

export default router;
