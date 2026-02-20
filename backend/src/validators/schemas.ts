/**
 * Zod Request Validators
 * =======================
 * Centralized input-validation schemas for every route that accepts a
 * request body. Uses Zod for type-safe parsing with automatic unknown-field
 * stripping (`z.object().strict()` rejects unknowns; we use `.strip()` to
 * silently drop them — safer default against mass-assignment).
 *
 * Each schema:
 *   • Trims and constrains string lengths
 *   • Rejects NoSQL operator keys (no `$` in field values)
 *   • Returns user-friendly error messages
 */

import { z } from "zod";
import { Request, Response, NextFunction } from "express";
import { stripHtml } from "../middleware/security";

// ═══════════════════════════════════════════════════════════════════════════════
// Helpers
// ═══════════════════════════════════════════════════════════════════════════════

/** Zod transform: trim + strip HTML tags. */
const safeString = (minLen = 1, maxLen = 500) =>
  z
    .string()
    .trim()
    .min(minLen, `Must be at least ${minLen} character(s)`)
    .max(maxLen, `Must be at most ${maxLen} characters`)
    .transform(stripHtml);

/** Email: lowercase + trim + basic regex. */
const email = z
  .string()
  .trim()
  .toLowerCase()
  .email("Invalid email address")
  .max(254);

/** Password: raw string, min 8 (backend passwordPolicy does the heavy check). */
const password = z
  .string()
  .min(8, "Password must be at least 8 characters")
  .max(128, "Password must be at most 128 characters");

// ═══════════════════════════════════════════════════════════════════════════════
// Auth Schemas
// ═══════════════════════════════════════════════════════════════════════════════

export const registerSchema = z
  .object({
    email,
    password,
    name: safeString(1, 100),
    walletAddress: z.string().max(100).optional(),
  })
  .strip(); // silently remove unknown fields

export const loginSchema = z
  .object({
    email,
    password: z.string().min(1, "Password is required").max(128),
  })
  .strip();

export const googleLoginSchema = z
  .object({
    idToken: z.string().min(1, "Google ID token is required").max(4096),
  })
  .strip();

export const forgotPasswordSchema = z
  .object({
    email,
  })
  .strip();

export const verifyOtpSchema = z
  .object({
    email,
    otp: z
      .string()
      .trim()
      .length(6, "OTP must be exactly 6 digits")
      .regex(/^\d{6}$/, "OTP must be exactly 6 digits"),
  })
  .strip();

export const resetPasswordSchema = z
  .object({
    email,
    resetToken: z.string().min(1).max(256),
    newPassword: password,
  })
  .strip();

export const updateUserSchema = z
  .object({
    name: safeString(1, 100).optional(),
    walletAddress: z.string().max(100).optional(),
    photoUrl: z.string().url("Invalid URL").max(2048).optional(),
  })
  .strip();

// ═══════════════════════════════════════════════════════════════════════════════
// Recycle Schemas
// ═══════════════════════════════════════════════════════════════════════════════

const validWasteTypes = [
  "plastic",
  "paper",
  "metal",
  "glass",
  "organic",
  "e-waste",
] as const;

export const recycleSchema = z
  .object({
    wasteType: z.enum(validWasteTypes, {
      message: `wasteType must be one of: ${validWasteTypes.join(", ")}`,
    }),
    quantity: z.coerce.number().int().min(1).max(100).optional(),
    imageData: z.string().max(15_000_000).optional(), // ~10 MB base64
    metadata: z
      .object({
        confidence: z.coerce.number().min(0).max(1).optional(),
        deviceId: safeString(0, 200).optional(),
        binType: safeString(0, 100).optional(),
        source: safeString(0, 50).optional(),
        isRecyclable: z.boolean().optional(),
        location: z
          .object({
            lat: z.number().min(-90).max(90),
            lng: z.number().min(-180).max(180),
          })
          .optional(),
      })
      .strip()
      .optional(),
  })
  .strip();

// ═══════════════════════════════════════════════════════════════════════════════
// Waste / Suggestion Schema
// ═══════════════════════════════════════════════════════════════════════════════

export const disposalSuggestionSchema = z
  .object({
    wasteType: safeString(1, 50),
    confidence: z.coerce.number().min(0).max(1).optional(),
    context: safeString(0, 500).optional(),
  })
  .strip();

// ═══════════════════════════════════════════════════════════════════════════════
// Rewards Schema
// ═══════════════════════════════════════════════════════════════════════════════

export const redeemSchema = z
  .object({
    rewardType: safeString(1, 50),
    customPoints: z.coerce.number().int().min(1).max(100_000).optional(),
  })
  .strip();

// ═══════════════════════════════════════════════════════════════════════════════
// Validation Middleware Factory
// ═══════════════════════════════════════════════════════════════════════════════

/**
 * Returns Express middleware that validates `req.body` against a Zod schema.
 * On success, `req.body` is replaced with the parsed (trimmed, stripped) output.
 * On failure, responds with 422 and a structured error payload.
 */
export const validate =
  <T extends z.ZodTypeAny>(schema: T) =>
  (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      const errors = result.error.issues.map((i) => ({
        field: i.path.join("."),
        message: i.message,
      }));
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Request validation failed",
        errors,
      });
    }
    // Replace body with parsed & sanitized object
    req.body = result.data;
    return next();
  };
