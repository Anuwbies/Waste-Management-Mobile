/**
 * Export Helpers
 * ==============
 * Shared filter‐builder logic used by both exportService and archiveService.
 */

import { FilterQuery } from "mongoose";
import { IAdminAuditEvent } from "../models/AdminAuditEvent";

/**
 * Convert the `filters` object sent from the frontend into a Mongoose query.
 * Mirrors the query builder in adminAuditService but works from a generic Record.
 */
export function buildFilterFromBody(
  f: Record<string, unknown>,
): FilterQuery<IAdminAuditEvent> {
  const filter: FilterQuery<IAdminAuditEvent> = {};

  if (f.search && typeof f.search === "string") {
    const escaped = f.search.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    filter.$or = [
      { userEmail: { $regex: escaped, $options: "i" } },
      { walletAddress: { $regex: escaped, $options: "i" } },
      { txHash: { $regex: escaped, $options: "i" } },
      { eventHash: { $regex: escaped, $options: "i" } },
    ];
  }

  if (f.activityType && typeof f.activityType === "string") {
    filter.activityType = f.activityType as IAdminAuditEvent["activityType"];
  }
  if (f.status && typeof f.status === "string") {
    filter.status = f.status as IAdminAuditEvent["status"];
  }
  if (f.wasteType && typeof f.wasteType === "string") {
    filter.wasteType = f.wasteType;
  }

  if (f.startDate || f.endDate) {
    filter.createdAt = {};
    if (f.startDate && typeof f.startDate === "string") {
      filter.createdAt.$gte = new Date(f.startDate);
    }
    if (f.endDate && typeof f.endDate === "string") {
      const end = new Date(f.endDate);
      end.setHours(23, 59, 59, 999);
      filter.createdAt.$lte = end;
    }
  }

  return filter;
}
