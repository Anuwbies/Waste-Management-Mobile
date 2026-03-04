/**
 * Admin Routes
 * ============
 * All /admin/* endpoints.
 *
 * Public:
 *   POST /admin/login         – admin login (rate-limited)
 *
 * Protected (JWT + admin role):
 *   POST /admin/logout
 *   GET  /admin/dashboard
 *   GET  /admin/audit                – paginated + filtered list
 *   GET  /admin/audit/:id            – single event detail
 *   PATCH /admin/audit/:id/note      – update admin notes
 *   POST /admin/audit/backfill       – trigger backfill from source collections
 *   POST /admin/export               – CSV / JSON download
 *   POST /admin/archive              – create ZIP archive
 *   GET  /admin/archive/list         – list archives
 *   GET  /admin/archive/download/:id – download archive ZIP
 *   DELETE /admin/archive/:id        – delete archive
 */

import { Router } from "express";

// ── Middleware ────────────────────────────────────────────────────────────────
import { adminAuth, adminOnly } from "../middleware/adminAuth";
import {
  adminLoginLimiter,
  adminApiLimiter,
  adminExportLimiter,
} from "../middleware/rateLimit";
import { validate } from "../validators/schemas";
import {
  adminLoginSchema,
  patchNoteSchema,
  exportSchema,
  createArchiveSchema,
} from "../validators/adminSchemas";

// ── Controllers ──────────────────────────────────────────────────────────────
import { adminLogin, adminLogout } from "../controllers/adminAuthController";
import { getDashboard } from "../controllers/adminDashboardController";
import {
  listAuditLogs,
  getAuditDetailCtrl,
  patchAuditNote,
  triggerBackfill,
} from "../controllers/adminAuditController";
import { exportAuditLogs } from "../controllers/adminExportController";
import {
  createArchiveCtrl,
  listArchivesCtrl,
  downloadArchiveCtrl,
  deleteArchiveCtrl,
} from "../controllers/adminArchiveController";

const router = Router();

// ═══════════════════════════════════════════════════════════════════════════════
// Public
// ═══════════════════════════════════════════════════════════════════════════════

router.post("/login", adminLoginLimiter, validate(adminLoginSchema), adminLogin);

// ═══════════════════════════════════════════════════════════════════════════════
// Protected — all routes below require JWT + admin role
// ═══════════════════════════════════════════════════════════════════════════════

router.use(adminAuth, adminOnly, adminApiLimiter);

// Auth
router.post("/logout", adminLogout);

// Dashboard
router.get("/dashboard", getDashboard);

// Audit logs
router.get("/audit", listAuditLogs);
router.get("/audit/:id", getAuditDetailCtrl);
router.patch("/audit/:id/note", validate(patchNoteSchema), patchAuditNote);
router.post("/audit/backfill", triggerBackfill);

// Export (CSV / JSON blob)
router.post("/export", adminExportLimiter, validate(exportSchema), exportAuditLogs);

// Archives (ZIP)
router.post("/archive", adminExportLimiter, validate(createArchiveSchema), createArchiveCtrl);
router.get("/archive/list", listArchivesCtrl);
router.get("/archive/download/:id", downloadArchiveCtrl);
router.delete("/archive/:id", deleteArchiveCtrl);

export default router;
