/**
 * Admin Audit Service
 * ===================
 * Provides the data layer for the admin audit trail:
 *  - Backfill from existing collections → AdminAuditEvent
 *  - Paginated + filtered list queries
 *  - Single-record detail
 *  - Note / flag operations
 */

import { FilterQuery, Types } from "mongoose";
import AdminAuditEvent, {
  IAdminAuditEvent,
  AuditActivityType,
  AuditStatus,
} from "../models/AdminAuditEvent";
import WasteClassification from "../models/WasteClassification";
import RecyclingEvent from "../models/RecyclingEvent";
import RewardTransaction from "../models/RewardTransaction";
import User from "../models/User";
import { logger } from "../config/logger";

// ─── Query interfaces ──────────────────────────────────────────────────────

export interface AuditQueryParams {
  page: number;
  limit: number;
  search?: string;
  activityType?: string;
  status?: string;
  wasteType?: string;
  startDate?: string;
  endDate?: string;
  minPoints?: number;
  maxPoints?: number;
  minConfidence?: number;
  maxConfidence?: number;
  flagged?: string;
  sortBy?: string;
  sortOrder?: "asc" | "desc";
}

export interface PaginatedAuditResult {
  data: IAdminAuditEvent[];
  total: number;
  page: number;
  limit: number;
  totalPages: number;
}

// ─── Build Mongo filter from query params ──────────────────────────────────

function buildFilter(q: AuditQueryParams): FilterQuery<IAdminAuditEvent> {
  const filter: FilterQuery<IAdminAuditEvent> = {};

  // Free-text search (email / wallet / txHash / eventHash)
  if (q.search) {
    const escaped = q.search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const orFilters: FilterQuery<IAdminAuditEvent>[] = [
      { userEmail: { $regex: escaped, $options: "i" } },
      { userName: { $regex: escaped, $options: "i" } },
      { walletAddress: { $regex: escaped, $options: "i" } },
      { txHash: { $regex: escaped, $options: "i" } },
      { eventHash: { $regex: escaped, $options: "i" } },
    ];

    if (Types.ObjectId.isValid(q.search)) {
      orFilters.push({ userId: new Types.ObjectId(q.search) });
    }

    filter.$or = orFilters;
  }

  if (q.activityType) filter.activityType = q.activityType as AuditActivityType;
  if (q.status) filter.status = q.status as AuditStatus;
  if (q.wasteType) filter.wasteType = q.wasteType;

  // Date range
  if (q.startDate || q.endDate) {
    filter.createdAt = {};
    if (q.startDate) filter.createdAt.$gte = new Date(q.startDate);
    if (q.endDate) {
      const end = new Date(q.endDate);
      end.setHours(23, 59, 59, 999);
      filter.createdAt.$lte = end;
    }
  }

  // Points range
  if (q.minPoints !== undefined || q.maxPoints !== undefined) {
    filter.points = {};
    if (q.minPoints !== undefined) filter.points.$gte = q.minPoints;
    if (q.maxPoints !== undefined) filter.points.$lte = q.maxPoints;
  }

  // Confidence range
  if (q.minConfidence !== undefined || q.maxConfidence !== undefined) {
    filter.confidence = {};
    if (q.minConfidence !== undefined) filter.confidence.$gte = q.minConfidence;
    if (q.maxConfidence !== undefined) filter.confidence.$lte = q.maxConfidence;
  }

  // Flagged
  if (q.flagged === "true") filter.flagged = true;
  if (q.flagged === "false") filter.flagged = false;

  return filter;
}

// ─── Public API ────────────────────────────────────────────────────────────

export async function queryAuditLogs(
  params: AuditQueryParams,
): Promise<PaginatedAuditResult> {
  const { page, limit, sortBy = "createdAt", sortOrder = "desc" } = params;
  const filter = buildFilter(params);
  const skip = (page - 1) * limit;
  const sortDir = sortOrder === "asc" ? 1 : -1;

  const [data, total] = await Promise.all([
    AdminAuditEvent.find(filter)
      .sort({ [sortBy]: sortDir })
      .skip(skip)
      .limit(limit)
      .lean(),
    AdminAuditEvent.countDocuments(filter),
  ]);

  return {
    data: data as unknown as IAdminAuditEvent[],
    total,
    page,
    limit,
    totalPages: Math.ceil(total / limit) || 1,
  };
}

export async function getAuditDetail(
  id: string,
): Promise<IAdminAuditEvent | null> {
  if (!Types.ObjectId.isValid(id)) return null;
  return AdminAuditEvent.findById(id).lean() as unknown as IAdminAuditEvent | null;
}

export async function updateNote(
  id: string,
  note: string,
  flagged?: boolean,
): Promise<IAdminAuditEvent | null> {
  if (!Types.ObjectId.isValid(id)) return null;
  const update: Record<string, unknown> = { adminNotes: note };
  if (flagged !== undefined) update.flagged = flagged;
  return AdminAuditEvent.findByIdAndUpdate(id, { $set: update }, { new: true }).lean() as unknown as IAdminAuditEvent | null;
}

// ─── Backfill helper ───────────────────────────────────────────────────────
// Populates AdminAuditEvent from existing WasteClassification, RecyclingEvent,
// and RewardTransaction collections. Safe to run multiple times (upserts).

export async function backfillAuditEvents(): Promise<{
  classifications: number;
  recyclingEvents: number;
  rewardTransactions: number;
}> {
  const stats = { classifications: 0, recyclingEvents: 0, rewardTransactions: 0 };

  // ── WasteClassifications → type=scan ──
  const classifications = await WasteClassification.find()
    .populate("userId", "email name walletAddress")
    .lean();

  for (const c of classifications) {
    const user = c.userId as unknown as {
      _id: Types.ObjectId;
      email: string;
      name: string;
      walletAddress?: string;
    };
    if (!user?._id) continue;

    await AdminAuditEvent.findOneAndUpdate(
      { classificationId: c._id },
      {
        $setOnInsert: {
          userId: user._id,
          userEmail: user.email ?? "",
          userName: user.name ?? "",
          walletAddress: user.walletAddress,
          activityType: "scan" as AuditActivityType,
          status: (c.status ?? "pending") as AuditStatus,
          wasteType: c.wasteType,
          confidence: c.confidence,
          rawLabel: c.rawLabel,
          modelVersion: c.modelVersion,
          imageUrl: c.imageUrl,
          imageHash: c.imageHash,
          points: c.rewardPoints,
          classificationId: c._id,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
        },
      },
      { upsert: true, new: true, timestamps: false },
    );
    stats.classifications++;
  }

  // ── RecyclingEvents → type=recycle ──
  const events = await RecyclingEvent.find()
    .populate("userId", "email name walletAddress")
    .lean();

  for (const e of events) {
    const user = e.userId as unknown as {
      _id: Types.ObjectId;
      email: string;
      name: string;
      walletAddress?: string;
    };
    if (!user?._id) continue;

    const statusMap: Record<string, AuditStatus> = {
      pending: "pending",
      confirmed: "confirmed",
      failed: "failed",
      duplicate: "duplicate",
    };

    await AdminAuditEvent.findOneAndUpdate(
      { recyclingEventId: e._id },
      {
        $setOnInsert: {
          userId: user._id,
          userEmail: user.email ?? "",
          userName: user.name ?? "",
          walletAddress: user.walletAddress ?? e.userWallet,
          activityType: "recycle" as AuditActivityType,
          status: statusMap[e.status] ?? "pending",
          wasteType: e.wasteType,
          confidence: e.aiConfidence,
          imageHash: e.imageHash,
          points: e.rewardPoints,
          txHash: e.txHash,
          chainId: e.chainId,
          eventHash: e.eventHash,
          txStatus: e.status === "confirmed" ? "success" : e.status === "failed" ? "failed" : "pending",
          recyclingEventId: e._id,
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
        },
      },
      { upsert: true, new: true, timestamps: false },
    );
    stats.recyclingEvents++;
  }

  // ── RewardTransactions → type=earn/redeem ──
  const txs = await RewardTransaction.find()
    .populate("userId", "email name walletAddress")
    .lean();

  for (const tx of txs) {
    const user = tx.userId as unknown as {
      _id: Types.ObjectId;
      email: string;
      name: string;
      walletAddress?: string;
    };
    if (!user?._id) continue;

    const activityMap: Record<string, AuditActivityType> = {
      earn: "recycle",
      redeem: "redeem",
      sync: "recycle",
      adjustment: "recycle",
    };

    const statusMap: Record<string, AuditStatus> = {
      pending: "pending",
      submitted: "pending",
      confirmed: "confirmed",
      failed: "failed",
    };

    await AdminAuditEvent.findOneAndUpdate(
      { rewardTransactionId: tx._id },
      {
        $setOnInsert: {
          userId: user._id,
          userEmail: user.email ?? "",
          userName: user.name ?? "",
          walletAddress: user.walletAddress,
          activityType: activityMap[tx.type] ?? "recycle",
          status: statusMap[tx.status] ?? "pending",
          points: tx.points,
          txHash: tx.txHash,
          chainId: tx.chainId,
          eventHash: tx.eventHash,
          txStatus: tx.status === "confirmed" ? "success" : tx.status === "failed" ? "failed" : "pending",
          rewardTransactionId: tx._id,
          rewardCalculation: tx.description,
          createdAt: tx.createdAt,
          updatedAt: tx.updatedAt,
        },
      },
      { upsert: true, new: true, timestamps: false },
    );
    stats.rewardTransactions++;
  }

  logger.info("Backfill complete", stats);
  return stats;
}

// ─── Convenience: record a new audit event in real-time ─────────────────────

export async function recordAuditEvent(
  data: Partial<IAdminAuditEvent>,
): Promise<IAdminAuditEvent> {
  const event = new AdminAuditEvent(data);
  return event.save();
}

// ─── Count helpers for dashboard ────────────────────────────────────────────

export async function countToday(
  filter: FilterQuery<IAdminAuditEvent> = {},
): Promise<number> {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  return AdminAuditEvent.countDocuments({
    ...filter,
    createdAt: { $gte: startOfDay },
  });
}

export async function sumPointsToday(): Promise<number> {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const result = await AdminAuditEvent.aggregate([
    {
      $match: {
        createdAt: { $gte: startOfDay },
        status: { $in: ["approved", "confirmed"] },
        points: { $exists: true, $gt: 0 },
      },
    },
    { $group: { _id: null, total: { $sum: "$points" } } },
  ]);
  return result[0]?.total ?? 0;
}
