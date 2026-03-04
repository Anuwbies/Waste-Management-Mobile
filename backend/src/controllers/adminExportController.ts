/**
 * Admin Export Controller
 * =======================
 * POST /admin/export
 * Body: { format: "csv" | "json", filters: {...} }
 * Responds with a downloadable file blob.
 */

import { Response } from "express";
import { AuthRequest } from "../middleware/auth";
import { generateExport } from "../services/exportService";
import { logger } from "../config/logger";

export const exportAuditLogs = async (req: AuthRequest, res: Response) => {
  try {
    const { format, filters } = req.body;

    if (!format || !["csv", "json"].includes(format)) {
      return res
        .status(422)
        .json({ message: "format must be 'csv' or 'json'" });
    }

    const { stream, recordCount, contentType, extension } =
      await generateExport({
        format,
        filters: filters ?? {},
      });

    const filename = `audit-export-${Date.now()}.${extension}`;

    res.setHeader("Content-Type", contentType);
    res.setHeader(
      "Content-Disposition",
      `attachment; filename="${filename}"`,
    );
    res.setHeader("X-Record-Count", String(recordCount));

    stream.pipe(res);
  } catch (error) {
    logger.error("exportAuditLogs error:", error);
    return res.status(500).json({ message: "Export failed" });
  }
};
