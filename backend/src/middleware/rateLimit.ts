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

import rateLimit, { ipKeyGenerator } from "express-rate-limit";

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
    // Combine IPv6-safe IP + email to limit per-account brute-force too
    const ip = ipKeyGenerator(req.ip ?? "0.0.0.0");
    const email =
      typeof req.body?.email === "string"
        ? req.body.email.toLowerCase().trim()
        : "";
    return `${ip}:${email}`;
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

// ---------------------------------------------------------------------------
// Upload / classify limiter  –  30 req / 5 min per IP
// ---------------------------------------------------------------------------
export const uploadLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_REQUESTS",
    message: "Too many upload requests. Please slow down.",
  },
});

// ---------------------------------------------------------------------------
// LLM suggestion limiter  –  15 req / 5 min per IP (expensive upstream call)
// ---------------------------------------------------------------------------
export const suggestionLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_REQUESTS",
    message: "Too many suggestion requests. Please wait before trying again.",
  },
});

// ---------------------------------------------------------------------------
// Recycle / reward limiter  –  60 req / 5 min per IP
// ---------------------------------------------------------------------------
export const apiLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_REQUESTS",
    message: "Too many requests. Please try again shortly.",
  },
});

// ---------------------------------------------------------------------------
// Global fallback limiter  –  200 req / 5 min per IP (DoS safety net)
// ---------------------------------------------------------------------------
export const globalLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_REQUESTS",
    message: "Rate limit exceeded. Please try again later.",
  },
});

// ---------------------------------------------------------------------------
// Admin login limiter  –  5 requests / 10 min per IP
// ---------------------------------------------------------------------------
export const adminLoginLimiter = rateLimit({
  windowMs: 10 * 60 * 1000,
  max: 15,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_ATTEMPTS",
    message: "Too many admin login attempts. Please try again later.",
  },
  keyGenerator: (req) => {
    const ip = ipKeyGenerator(req.ip ?? "0.0.0.0");
    const email =
      typeof req.body?.email === "string"
        ? req.body.email.toLowerCase().trim()
        : "";
    return `admin:${ip}:${email}`;
  },
});

// ---------------------------------------------------------------------------
// Admin API limiter  –  120 requests / 5 min per IP (read-heavy dashboards)
// ---------------------------------------------------------------------------
export const adminApiLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_REQUESTS",
    message: "Admin API rate limit exceeded. Please try again shortly.",
  },
});

// ---------------------------------------------------------------------------
// Admin export / archive limiter  –  10 requests / 5 min per IP
// ---------------------------------------------------------------------------
export const adminExportLimiter = rateLimit({
  windowMs: 5 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    code: "TOO_MANY_REQUESTS",
    message: "Too many export requests. Please wait before trying again.",
  },
});
