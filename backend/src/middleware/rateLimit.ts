/**
 * Auth Rate Limiter Middleware
 *
 * Provides per-endpoint rate limiting for authentication routes:
 *  - Login:           5 attempts per 10 minutes (per IP)
 *  - Forgot-password: 3 attempts per 10 minutes (per IP)
 *  - Verify-OTP:      5 attempts per 10 minutes (per IP)
 *
 * Uses express-rate-limit with an in-memory store (swap for Redis in
 * production if running multiple instances).
 */

import rateLimit from "express-rate-limit";

// ---------------------------------------------------------------------------
// Login rate limiter  –  5 requests / 10 min per IP
// ---------------------------------------------------------------------------
export const loginLimiter = rateLimit({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 10, // generous for dev; tighten in prod
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_ATTEMPTS",
    message: "Too many login attempts. Please try again later.",
  },
  keyGenerator: (req) => {
    // Combine IP + email to limit per-account brute-force too
    const email =
      typeof req.body?.email === "string"
        ? req.body.email.toLowerCase().trim()
        : "";
    return `${req.ip}:${email}`;
  },
});

// ---------------------------------------------------------------------------
// Forgot-password rate limiter  –  3 requests / 10 min per IP
// ---------------------------------------------------------------------------
export const forgotPasswordLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 3,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_ATTEMPTS",
    message: "Too many password-reset requests. Please try again later.",
  },
});

// ---------------------------------------------------------------------------
// OTP verification limiter  –  5 requests / 10 min per IP
// ---------------------------------------------------------------------------
export const otpVerifyLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_ATTEMPTS",
    message: "Too many OTP verification attempts. Please try again later.",
  },
});

// ---------------------------------------------------------------------------
// Generic auth limiter (register / google etc.)  –  15 req / 10 min
// ---------------------------------------------------------------------------
export const authGeneralLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_ATTEMPTS",
    message: "Too many requests. Please try again later.",
  },
});
