/**
 * Export Service
 * ==============
 * Generates CSV / JSON blobs from audit query results and streams them
 * back to the caller as downloadable files.
 */

import { Readable } from "stream";
import AdminAuditEvent, { IAdminAuditEvent } from "../models/AdminAuditEvent";
import { buildFilterFromBody } from "./exportHelpers";
import { logger } from "../config/logger";

export interface ExportOptions {
  format: "csv" | "json";
  filters: Record<string, unknown>;
}

// CSV column config
const CSV_COLUMNS: { header: string; key: keyof IAdminAuditEvent | string }[] = [
  { header: "ID", key: "_id" },
  { header: "Timestamp", key: "createdAt" },
  { header: "User Email", key: "userEmail" },
  { header: "User Name", key: "userName" },
  { header: "Wallet", key: "walletAddress" },
  { header: "Activity", key: "activityType" },
  { header: "Status", key: "status" },
  { header: "Waste Type", key: "wasteType" },
  { header: "Confidence", key: "confidence" },
  { header: "Points", key: "points" },
  { header: "TxHash", key: "txHash" },
  { header: "EventHash", key: "eventHash" },
  { header: "Chain ID", key: "chainId" },
  { header: "Flagged", key: "flagged" },
  { header: "Notes", key: "adminNotes" },
];

function escapeCsv(val: unknown): string {
  if (val === null || val === undefined) return "";
  const s = String(val);
  if (s.includes(",") || s.includes('"') || s.includes("\n")) {
    return `"${s.replace(/"/g, '""')}"`;
  }
  return s;
}

function rowToCsv(doc: Record<string, unknown>): string {
  return CSV_COLUMNS.map((col) => escapeCsv(doc[col.key])).join(",");
}

/**
 * Generate a readable stream of the export file content.
 * Returns { stream, recordCount, contentType, extension }.
 */
export async function generateExport(opts: ExportOptions): Promise<{
  stream: Readable;
  recordCount: number;
  contentType: string;
  extension: string;
}> {
  const filter = buildFilterFromBody(opts.filters);
  const docs = await AdminAuditEvent.find(filter)
    .sort({ createdAt: -1 })
    .limit(50_000) // safety cap
    .lean();

  const recordCount = docs.length;
  logger.info(`Exporting ${recordCount} records as ${opts.format}`);

  if (opts.format === "json") {
    // Pretty-print JSON array
    const json = JSON.stringify(docs, null, 2);
    const stream = Readable.from([json]);
    return { stream, recordCount, contentType: "application/json", extension: "json" };
  }

  // CSV
  const header = CSV_COLUMNS.map((c) => c.header).join(",");
  const rows = docs.map((d) => rowToCsv(d as Record<string, unknown>));
  const csv = [header, ...rows].join("\n");
  const stream = Readable.from([csv]);
  return { stream, recordCount, contentType: "text/csv", extension: "csv" };
}
