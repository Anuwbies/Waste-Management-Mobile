/**
 * Global Error Handler Middleware
 * ================================
 * Catches all unhandled errors and returns safe, structured JSON responses.
 *
 * In **production**, stack traces and internal messages are hidden.
 * The `requestId` (if present) is included for correlation.
 */

import { Request, Response, NextFunction } from "express";

const isProduction = process.env.NODE_ENV === "production";

interface AppError extends Error {
  status?: number;
  code?: string;
  // Multer and other libraries attach these
  type?: string;
}

/**
 * Must be registered **after** all routes.
 * Express recognises this as an error handler because it has 4 params.
 */
export const globalErrorHandler = (
  err: AppError,
  req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  // ── Determine status code ─────────────────────────────────────────
  let status = err.status ?? 500;

  // Multer: invalid file type from fileFilter
  if (err.message?.toLowerCase().includes("invalid file type")) {
    status = 415;
  }
  // Multer: file too large
  if ((err as { code?: string }).code === "LIMIT_FILE_SIZE") {
    status = 413;
  }
  // CORS errors
  if (err.message?.includes("not allowed by CORS")) {
    status = 403;
  }
  // JSON parse errors (malformed body)
  if (err.type === "entity.parse.failed") {
    status = 400;
  }
  // Body too large (express.json limit)
  if (err.type === "entity.too.large") {
    status = 413;
  }

  // ── Build safe response ───────────────────────────────────────────
  const response: Record<string, unknown> = {
    code: err.code ?? (status >= 500 ? "INTERNAL_ERROR" : "BAD_REQUEST"),
    message: status >= 500 && isProduction
      ? "An unexpected error occurred"
      : err.message || "An unexpected error occurred",
  };

  // Attach requestId for correlation (set by requestIdMiddleware)
  if (req.requestId) {
    response.requestId = req.requestId;
  }

  // In dev, include stack trace for debugging
  if (!isProduction && err.stack) {
    response.stack = err.stack;
  }

  // ── Log server errors ─────────────────────────────────────────────
  if (status >= 500) {
    console.error(
      `[ERROR] ${req.method} ${req.originalUrl} ${status}`,
      req.requestId ? `reqId=${req.requestId}` : "",
      err.message,
      isProduction ? "" : err.stack,
    );
  }

  res.status(status).json(response);
};
