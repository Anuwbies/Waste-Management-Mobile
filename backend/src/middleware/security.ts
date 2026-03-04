/**
 * Security Middleware
 * ===================
 * Centralized security hardening: Helmet headers, Mongo-sanitize,
 * CORS allowlist, request-body size limits, and request-ID correlation.
 */

import helmet from "helmet";
import mongoSanitize from "express-mongo-sanitize";
import cors from "cors";
import { v4 as uuidv4 } from "uuid";
import { Request, Response, NextFunction } from "express";

// ─── Re-export for convenience ────────────────────────────────────────────────

export { helmet, mongoSanitize };

// ─── CORS allowlist ───────────────────────────────────────────────────────────

const ALLOWED_ORIGINS: (string | RegExp)[] = (() => {
  const envOrigins = process.env.CORS_ORIGINS; // comma-separated
  if (envOrigins) {
    return envOrigins.split(",").map((o) => o.trim()).filter(Boolean);
  }

  // Development defaults
  if (process.env.NODE_ENV !== "production") {
    return [
      "http://localhost:3000",
      "http://localhost:5000",
      "http://127.0.0.1:3000",
      "http://127.0.0.1:5000",
      "http://10.0.2.2:5000", // Android emulator → host
      /^http:\/\/192\.168\.\d{1,3}\.\d{1,3}(:\d+)?$/, // LAN dev
      "http://localhost:5173"
    ];
  }

  // Production: must be configured via env
  return [];
})();

export const corsOptions: cors.CorsOptions = {
  origin: (origin, callback) => {
    // Allow requests with no origin (mobile apps, curl, server-to-server)
    if (!origin) return callback(null, true);

    const allowed = ALLOWED_ORIGINS.some((o) =>
      o instanceof RegExp ? o.test(origin) : o === origin,
    );

    if (allowed) {
      callback(null, true);
    } else {
      callback(new Error(`Origin ${origin} not allowed by CORS`));
    }
  },
  credentials: true,
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization"],
  maxAge: 600, // preflight cache 10 min
};

// ─── Request-ID middleware ────────────────────────────────────────────────────

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      /** Unique request correlation ID (UUID v4) */
      requestId?: string;
    }
  }
}

/**
 * Attach a unique `requestId` (UUID v4) to every request.
 * Honour `X-Request-Id` from trusted upstream proxies if present.
 */
export const requestIdMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction,
): void => {
  const incoming =
    typeof req.headers["x-request-id"] === "string"
      ? req.headers["x-request-id"]
      : undefined;
  req.requestId = incoming || uuidv4();
  res.setHeader("X-Request-Id", req.requestId);
  next();
};

// ─── NoSQL operator stripping (defense-in-depth) ─────────────────────────────

/**
 * Deep-strip any key starting with `$` from an object.
 * This guards against NoSQL injection when `express-mongo-sanitize`
 * is somehow bypassed (e.g. nested JSON parsing).
 */
export const deepStripDollarKeys = (obj: unknown): unknown => {
  if (obj === null || obj === undefined) return obj;
  if (Array.isArray(obj)) return obj.map(deepStripDollarKeys);
  if (typeof obj === "object") {
    const clean: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
      if (key.startsWith("$")) continue; // drop operator keys
      clean[key] = deepStripDollarKeys(value);
    }
    return clean;
  }
  return obj;
};

// ─── XSS / HTML-tag strip helper ─────────────────────────────────────────────

/** Strip HTML tags from a string (simple but effective for API text fields). */
export const stripHtml = (input: string): string =>
  input.replace(/<[^>]*>/g, "");

// ─── Helmet configuration ─────────────────────────────────────────────────────

export const helmetMiddleware = helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'none'"],
      scriptSrc: ["'none'"],
      styleSrc: ["'none'"],
      imgSrc: ["'self'"],
      connectSrc: ["'self'"],
    },
  },
  crossOriginEmbedderPolicy: false, // API – not embedding resources
  crossOriginResourcePolicy: { policy: "cross-origin" }, // Allow mobile clients
});
