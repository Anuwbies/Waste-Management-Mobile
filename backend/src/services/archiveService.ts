/**
 * Archive Service
 * ===============
 * Creates ZIP archives of audit data between date ranges, stores them on disk,
 * and manages the corresponding AdminArchive metadata records.
 */

import fs from "fs";
import path from "path";
import archiver from "archiver";
import AdminArchive, { IAdminArchive } from "../models/AdminArchive";
import AdminAuditEvent from "../models/AdminAuditEvent";
import { logger } from "../config/logger";
import { Types } from "mongoose";

// ─── Storage paths ─────────────────────────────────────────────────────────

const STORAGE_ROOT = path.resolve(__dirname, "..", "..", "storage");
const ARCHIVES_DIR = path.join(STORAGE_ROOT, "archives");

/** Ensure storage directories exist */
function ensureDirs() {
  for (const dir of [STORAGE_ROOT, ARCHIVES_DIR]) {
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
  }
}

// ─── Create archive ────────────────────────────────────────────────────────

export async function createArchive(
  adminId: string,
  startDate: string,
  endDate: string,
): Promise<IAdminArchive> {
  ensureDirs();

  // Create metadata record first (status=processing)
  const archive = await AdminArchive.create({
    createdBy: new Types.ObjectId(adminId),
    startDate: new Date(startDate),
    endDate: new Date(endDate),
    status: "processing",
  });

  // Run ZIP generation async (fire-and-forget with error capture)
  generateZip(archive._id as Types.ObjectId, startDate, endDate).catch((err) => {
    logger.error("Archive generation failed:", err);
    AdminArchive.findByIdAndUpdate(archive._id, {
      status: "error",
      errorMessage: (err as Error).message,
    }).catch(() => {});
  });

  return archive;
}

async function generateZip(
  archiveId: Types.ObjectId,
  startDate: string,
  endDate: string,
): Promise<void> {
  const start = new Date(startDate);
  const end = new Date(endDate);
  end.setHours(23, 59, 59, 999);

  // Fetch all audit events in range
  const docs = await AdminAuditEvent.find({
    createdAt: { $gte: start, $lte: end },
  })
    .sort({ createdAt: -1 })
    .limit(100_000)
    .lean();

  const zipFileName = `archive-${archiveId.toString()}.zip`;
  const zipPath = path.join(ARCHIVES_DIR, zipFileName);
  const output = fs.createWriteStream(zipPath);
  const zip = archiver("zip", { zlib: { level: 6 } });

  return new Promise<void>((resolve, reject) => {
    output.on("close", async () => {
      const fileSize = zip.pointer();
      await AdminArchive.findByIdAndUpdate(archiveId, {
        status: "ready",
        recordCount: docs.length,
        fileSize,
        filePath: zipPath,
      });
      logger.info(`Archive ${archiveId} ready: ${docs.length} records, ${fileSize} bytes`);
      resolve();
    });

    zip.on("error", reject);
    zip.pipe(output);

    // audit_logs.json
    zip.append(JSON.stringify(docs, null, 2), { name: "audit_logs.json" });

    // audit_logs.csv
    const csvHeader =
      "ID,Timestamp,Email,Name,Activity,Status,WasteType,Confidence,Points,TxHash,EventHash,Flagged\n";
    const csvRows = docs
      .map((d) => {
        const row = [
          d._id,
          d.createdAt?.toISOString?.() ?? "",
          d.userEmail ?? "",
          d.userName ?? "",
          d.activityType ?? "",
          d.status ?? "",
          d.wasteType ?? "",
          d.confidence ?? "",
          d.points ?? "",
          d.txHash ?? "",
          d.eventHash ?? "",
          d.flagged ? "true" : "false",
        ];
        return row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(",");
      })
      .join("\n");
    zip.append(csvHeader + csvRows, { name: "audit_logs.csv" });

    // meta.json
    const meta = {
      generatedAt: new Date().toISOString(),
      dateRange: { start: startDate, end: endDate },
      recordCount: docs.length,
      archiveId: archiveId.toString(),
    };
    zip.append(JSON.stringify(meta, null, 2), { name: "meta.json" });

    zip.finalize();
  });
}

// ─── List archives ─────────────────────────────────────────────────────────

export async function listArchives(): Promise<IAdminArchive[]> {
  return AdminArchive.find().sort({ createdAt: -1 }).lean() as unknown as IAdminArchive[];
}

// ─── Get archive path for download ─────────────────────────────────────────

export async function getArchiveForDownload(
  id: string,
): Promise<{ archive: IAdminArchive; filePath: string } | null> {
  if (!Types.ObjectId.isValid(id)) return null;
  const archive = await AdminArchive.findById(id).lean() as unknown as IAdminArchive | null;
  if (!archive || archive.status !== "ready" || !archive.filePath) return null;
  if (!fs.existsSync(archive.filePath)) return null;
  return { archive, filePath: archive.filePath };
}

// ─── Delete archive ────────────────────────────────────────────────────────

export async function deleteArchive(id: string): Promise<boolean> {
  if (!Types.ObjectId.isValid(id)) return false;
  const archive = await AdminArchive.findById(id);
  if (!archive) return false;

  // Remove file from disk
  if (archive.filePath && fs.existsSync(archive.filePath)) {
    fs.unlinkSync(archive.filePath);
  }

  await AdminArchive.findByIdAndDelete(id);
  return true;
}
