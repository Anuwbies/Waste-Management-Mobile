/**
 * Admin Audit Controller
 * ======================
 * GET    /admin/audit          → paginated + filtered list
 * GET    /admin/audit/:id      → single record detail
 * PATCH  /admin/audit/:id/note → update admin notes
 */

import { Response } from "express";
import { AuthRequest } from "../middleware/auth";
import {
  queryAuditLogs,
  getAuditDetail,
  updateNote,
  backfillAuditEvents,
  AuditQueryParams,
} from "../services/adminAuditService";
import { logger } from "../config/logger";

/**
 * GET /admin/audit
 * Query params → page, limit, search, activityType, status, wasteType,
 *                startDate, endDate, sortBy, sortOrder, flagged,
 *                minPoints, maxPoints, minConfidence, maxConfidence
 */
export const listAuditLogs = async (req: AuthRequest, res: Response) => {
  try {
    const q = req.query;

    const params: AuditQueryParams = {
      page: Math.max(1, parseInt(q.page as string, 10) || 1),
      limit: Math.min(100, Math.max(1, parseInt(q.limit as string, 10) || 20)),
      search: ((q.q as string) || (q.search as string) || "").trim() || undefined,
      activityType: (q.activityType as string) || undefined,
      status: (q.status as string) || undefined,
      wasteType: (q.wasteType as string) || undefined,
      startDate: (q.startDate as string) || undefined,
      endDate: (q.endDate as string) || undefined,
      minPoints: q.minPoints ? parseFloat(q.minPoints as string) : undefined,
      maxPoints: q.maxPoints ? parseFloat(q.maxPoints as string) : undefined,
      minConfidence: q.minConfidence
        ? parseFloat(q.minConfidence as string)
        : undefined,
      maxConfidence: q.maxConfidence
        ? parseFloat(q.maxConfidence as string)
        : undefined,
      flagged: (q.flagged as string) || undefined,
      sortBy: (q.sortBy as string) || "createdAt",
      sortOrder: (q.sortOrder as "asc" | "desc") || "desc",
    };

    const result = await queryAuditLogs(params);

    // Map to the shape the frontend PaginatedResponse<AuditLog> expects
    const mapped = result.data.map((d) => ({
      id: (d._id as unknown as { toString: () => string }).toString(),
      timestamp: d.createdAt,
      userEmail: d.userEmail,
      userId: d.userId?.toString() ?? "",
      activityType: d.activityType,
      status: d.status,
      wasteType: d.wasteType,
      confidence: d.confidence,
      points: d.points,
      txHash: d.txHash,
      eventHash: d.eventHash,
      walletAddress: d.walletAddress,
      flagged: d.flagged,
      notePreview: d.adminNotes
        ? d.adminNotes.substring(0, 80)
        : undefined,
    }));

    return res.json({
      data: mapped,
      total: result.total,
      page: result.page,
      limit: result.limit,
      totalPages: result.totalPages,
    });
  } catch (error) {
    logger.error("listAuditLogs error:", error);
    return res.status(500).json({ message: "Failed to fetch audit logs" });
  }
};

/**
 * GET /admin/audit/:id
 * Returns full detail for one audit event — shape matches frontend AuditDetail.
 */
export const getAuditDetailCtrl = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const detail = await getAuditDetail(id);

    if (!detail) {
      return res.status(404).json({ message: "Audit record not found" });
    }

    // Shape the response to match the frontend AuditDetail interface
    const response = {
      id: (detail._id as unknown as { toString: () => string }).toString(),
      timestamp: detail.createdAt,
      userEmail: detail.userEmail,
      userId: detail.userId?.toString() ?? "",
      activityType: detail.activityType,
      status: detail.status,
      wasteType: detail.wasteType,
      confidence: detail.confidence,
      points: detail.points,
      txHash: detail.txHash,

      user: {
        id: detail.userId?.toString() ?? "",
        email: detail.userEmail,
        name: detail.userName,
        walletAddress: detail.walletAddress,
      },

      aiClassification: detail.wasteType
        ? {
            wasteType: detail.wasteType,
            confidence: detail.confidence ?? 0,
            modelVersion: detail.modelVersion ?? "unknown",
            imageHash: detail.imageHash,
            rawPredictions: detail.rawPredictions,
          }
        : undefined,

      reward: detail.points
        ? {
            points: detail.points,
            calculation: detail.rewardCalculation ?? "standard",
            bonusApplied: detail.bonusApplied ?? false,
          }
        : undefined,

      blockchain: detail.txHash
        ? {
            txHash: detail.txHash,
            blockNumber: detail.blockNumber ?? 0,
            chainId: detail.chainId ?? 0,
            contractAddress: detail.contractAddress ?? "",
            gasUsed: detail.gasUsed ?? "0",
            status: detail.txStatus ?? "pending",
          }
        : undefined,

      eventHash: detail.eventHash,
      imageHash: detail.imageHash,
      adminNotes: detail.adminNotes,
      flagged: detail.flagged,

      metadata: detail.metadata,
    };

    return res.json(response);
  } catch (error) {
    logger.error("getAuditDetail error:", error);
    return res.status(500).json({ message: "Failed to fetch audit detail" });
  }
};

/**
 * PATCH /admin/audit/:id/note
 * Body: { note: string, flagged?: boolean }
 */
export const patchAuditNote = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { note, flagged } = req.body;

    if (typeof note !== "string") {
      return res.status(422).json({ message: "Note must be a string" });
    }
    if (note.length > 5000) {
      return res.status(422).json({ message: "Note must be ≤ 5000 characters" });
    }

    const updated = await updateNote(id, note, flagged);
    if (!updated) {
      return res.status(404).json({ message: "Audit record not found" });
    }

    return res.json({
      id: (updated._id as unknown as { toString: () => string }).toString(),
      adminNotes: updated.adminNotes,
      flagged: updated.flagged,
    });
  } catch (error) {
    logger.error("patchAuditNote error:", error);
    return res.status(500).json({ message: "Failed to update note" });
  }
};

/**
 * POST /admin/audit/backfill
 * Triggers a backfill from existing collections → AdminAuditEvent.
 * Admin-only utility endpoint.
 */
export const triggerBackfill = async (req: AuthRequest, res: Response) => {
  try {
    const stats = await backfillAuditEvents();
    return res.json({ message: "Backfill complete", ...stats });
  } catch (error) {
    logger.error("triggerBackfill error:", error);
    return res.status(500).json({ message: "Backfill failed" });
  }
};
