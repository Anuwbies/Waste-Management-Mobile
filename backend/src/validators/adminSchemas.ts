/**
 * Admin Zod Validation Schemas
 * ============================
 * Input validation for all /admin/* endpoints.
 */

import { z } from "zod";

// ── Reusable helpers ────────────────────────────────────────────────────────

const email = z.string().trim().toLowerCase().email("Invalid email").max(254);

// ── Admin Login ─────────────────────────────────────────────────────────────

export const adminLoginSchema = z
  .object({
    email,
    password: z.string().min(1, "Password is required").max(128),
  })
  .strip();

// ── Audit Note Patch ────────────────────────────────────────────────────────

export const patchNoteSchema = z
  .object({
    adminNotes: z.string().max(2000, "Notes must be ≤ 2000 characters"),
  })
  .strip();

// ── Export Request ──────────────────────────────────────────────────────────

export const exportSchema = z
  .object({
    format: z.enum(["csv", "json"], {
      message: "format must be 'csv' or 'json'",
    }),
    filters: z
      .object({
        search: z.string().max(200).optional(),
        startDate: z.string().optional(),
        endDate: z.string().optional(),
        status: z.string().max(50).optional(),
        activityType: z.string().max(50).optional(),
        wasteType: z.string().max(50).optional(),
      })
      .strip()
      .optional(),
  })
  .strip();

// ── Archive Creation ────────────────────────────────────────────────────────

export const createArchiveSchema = z
  .object({
    startDate: z.string().refine((v) => !isNaN(Date.parse(v)), {
      message: "Invalid startDate",
    }),
    endDate: z.string().refine((v) => !isNaN(Date.parse(v)), {
      message: "Invalid endDate",
    }),
  })
  .strip();
