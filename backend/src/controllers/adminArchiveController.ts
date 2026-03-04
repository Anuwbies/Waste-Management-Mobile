/**
 * Admin Archive Controller
 * ========================
 * POST   /admin/archive              → create new archive
 * GET    /admin/archive/list          → list all archives
 * GET    /admin/archive/download/:id  → download ZIP
 * DELETE /admin/archive/:id           → delete archive
 */

import { Response } from "express";
import { AuthRequest } from "../middleware/auth";
import * as archiveSvc from "../services/archiveService";
import { logger } from "../config/logger";

/**
 * POST /admin/archive
 * Body: { startDate, endDate }
 */
export const createArchiveCtrl = async (req: AuthRequest, res: Response) => {
  try {
    const { startDate, endDate } = req.body;

    if (!startDate || !endDate) {
      return res
        .status(422)
        .json({ message: "startDate and endDate are required" });
    }

    // Basic date validation
    if (isNaN(Date.parse(startDate)) || isNaN(Date.parse(endDate))) {
      return res.status(422).json({ message: "Invalid date format" });
    }

    const archive = await archiveSvc.createArchive(
      req.userId!,
      startDate,
      endDate,
    );

    return res.status(201).json({
      id: (archive._id as unknown as { toString: () => string }).toString(),
      createdAt: archive.createdAt,
      startDate: archive.startDate,
      endDate: archive.endDate,
      recordCount: archive.recordCount,
      fileSize: archive.fileSize,
      status: archive.status,
    });
  } catch (error) {
    logger.error("createArchive error:", error);
    return res.status(500).json({ message: "Failed to create archive" });
  }
};

/**
 * GET /admin/archive/list
 */
export const listArchivesCtrl = async (_req: AuthRequest, res: Response) => {
  try {
    const archives = await archiveSvc.listArchives();

    const mapped = archives.map((a) => ({
      id: (a._id as unknown as { toString: () => string }).toString(),
      createdAt: a.createdAt,
      startDate: a.startDate,
      endDate: a.endDate,
      recordCount: a.recordCount,
      fileSize: a.fileSize,
      status: a.status,
    }));

    return res.json(mapped);
  } catch (error) {
    logger.error("listArchives error:", error);
    return res.status(500).json({ message: "Failed to list archives" });
  }
};

/**
 * GET /admin/archive/download/:id
 */
export const downloadArchiveCtrl = async (
  req: AuthRequest,
  res: Response,
) => {
  try {
    const { id } = req.params;
    const result = await archiveSvc.getArchiveForDownload(id);

    if (!result) {
      return res
        .status(404)
        .json({ message: "Archive not found or not ready" });
    }

    res.setHeader("Content-Type", "application/zip");
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="archive-${id}.zip"`,
    );

    return res.sendFile(result.filePath);
  } catch (error) {
    logger.error("downloadArchive error:", error);
    return res.status(500).json({ message: "Download failed" });
  }
};

/**
 * DELETE /admin/archive/:id
 */
export const deleteArchiveCtrl = async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const deleted = await archiveSvc.deleteArchive(id);

    if (!deleted) {
      return res.status(404).json({ message: "Archive not found" });
    }

    return res.json({ message: "Archive deleted" });
  } catch (error) {
    logger.error("deleteArchive error:", error);
    return res.status(500).json({ message: "Failed to delete archive" });
  }
};
