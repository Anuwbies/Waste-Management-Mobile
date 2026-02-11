import { Request, Response, NextFunction } from "express";
import { AuthRequest } from "./auth";

// =============================================================================
// ANSI Color Codes (no external dependency needed)
// =============================================================================

const colors = {
  reset: "\x1b[0m",
  bright: "\x1b[1m",
  dim: "\x1b[2m",

  // Foreground colors
  green: "\x1b[32m",
  cyan: "\x1b[36m",
  yellow: "\x1b[33m",
  red: "\x1b[31m",
  white: "\x1b[37m",
  gray: "\x1b[90m",
  magenta: "\x1b[35m",
  blue: "\x1b[34m",

  // Background colors
  bgGreen: "\x1b[42m",
  bgCyan: "\x1b[46m",
  bgYellow: "\x1b[43m",
  bgRed: "\x1b[41m",
};

// =============================================================================
// Configuration
// =============================================================================

const isDevelopment = process.env.NODE_ENV !== "production";

// =============================================================================
// Helper Functions
// =============================================================================

/**
 * Format timestamp for logging
 */
const getTimestamp = (): string => {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  const day = String(now.getDate()).padStart(2, "0");
  const hours = String(now.getHours()).padStart(2, "0");
  const minutes = String(now.getMinutes()).padStart(2, "0");
  const seconds = String(now.getSeconds()).padStart(2, "0");
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
};

/**
 * Get color based on HTTP status code
 */
const getStatusColor = (status: number): string => {
  if (status >= 500) return colors.red;
  if (status >= 400) return colors.yellow;
  if (status >= 300) return colors.cyan;
  if (status >= 200) return colors.green;
  return colors.white;
};

/**
 * Get route prefix icon based on URL path
 */
const getRouteIcon = (url: string): string => {
  if (url.startsWith("/recycle") || url.startsWith("/rewards")) return "⛓ ";
  if (url.startsWith("/auth")) return "🔐";
  if (url.startsWith("/waste")) return "♻ ";
  if (url.startsWith("/health")) return "💚";
  return "  ";
};

/**
 * Get method color
 */
const getMethodColor = (method: string): string => {
  switch (method) {
    case "GET":
      return colors.green;
    case "POST":
      return colors.blue;
    case "PUT":
    case "PATCH":
      return colors.yellow;
    case "DELETE":
      return colors.red;
    default:
      return colors.white;
  }
};

/**
 * Format duration with color based on speed
 */
const formatDuration = (ms: number): string => {
  if (ms < 100) return `${colors.green}${ms}ms${colors.reset}`;
  if (ms < 500) return `${colors.yellow}${ms}ms${colors.reset}`;
  return `${colors.red}${ms}ms${colors.reset}`;
};

/**
 * Get client IP address from request
 */
const getClientIp = (req: Request): string => {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string") {
    return forwarded.split(",")[0].trim();
  }
  if (Array.isArray(forwarded)) {
    return forwarded[0];
  }
  return req.socket.remoteAddress || "unknown";
};

/**
 * Truncate user ID for display
 */
const truncateId = (id: string | undefined): string => {
  if (!id) return "anonymous";
  if (id.length <= 10) return id;
  return `${id.substring(0, 7)}...`;
};

// =============================================================================
// Response Body Capture
// =============================================================================

interface LoggableResponse extends Response {
  _body?: unknown;
}

/**
 * Monkey-patch res.json to capture response body for logging
 */
const captureResponseBody = (res: LoggableResponse): void => {
  const originalJson = res.json.bind(res);
  res.json = (body: unknown) => {
    res._body = body;
    return originalJson(body);
  };
};

// =============================================================================
// Main Logger Middleware
// =============================================================================

/**
 * Express middleware for request/response logging
 *
 * Features:
 * - Timestamps
 * - Color-coded status (2xx green, 3xx cyan, 4xx yellow, 5xx red)
 * - Request duration in ms
 * - Route icons (⛓ blockchain, 🔐 auth, ♻ waste)
 * - User ID if authenticated
 * - IP address
 * - txHash extraction for blockchain routes
 */
export const loggerMiddleware = (
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  const startTime = Date.now();
  const authReq = req as AuthRequest;
  const loggableRes = res as LoggableResponse;

  // Capture response body for blockchain txHash extraction
  captureResponseBody(loggableRes);

  // Log on response finish
  res.on("finish", () => {
    const duration = Date.now() - startTime;
    const status = res.statusCode;
    const method = req.method;
    const url = req.originalUrl || req.url;

    // Build log components
    const timestamp = `${colors.gray}[${getTimestamp()}]${colors.reset}`;
    const icon = getRouteIcon(url);
    const methodStr = `${getMethodColor(method)}${method.padEnd(6)}${colors.reset}`;
    const urlStr = `${colors.white}${url}${colors.reset}`;
    const statusStr = `${getStatusColor(status)}${status}${colors.reset}`;
    const durationStr = formatDuration(duration);

    // Main log line
    let logLine = `${timestamp} ${icon} ${methodStr} ${urlStr} ${statusStr} ${durationStr}`;

    // Development mode: add extra details
    if (isDevelopment) {
      const ip = getClientIp(req);
      const userId = truncateId(authReq.userId);

      const details: string[] = [];

      // User info
      if (authReq.userId) {
        details.push(`${colors.magenta}User: ${userId}${colors.reset}`);
      }

      // IP address
      details.push(`${colors.gray}IP: ${ip}${colors.reset}`);

      // Extract txHash from blockchain responses
      const body = loggableRes._body as Record<string, unknown> | undefined;
      if (body && typeof body === "object") {
        // Check for txHash in various locations
        const txHash =
          body.txHash ||
          (body.event as Record<string, unknown> | undefined)?.txHash ||
          (body.transaction as Record<string, unknown> | undefined)?.txHash;

        if (txHash && typeof txHash === "string") {
          const shortHash = `${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}`;
          details.push(`${colors.cyan}txHash: ${shortHash}${colors.reset}`);
        }

        // Log error messages for failed requests
        if (status >= 400 && body.message) {
          details.push(`${colors.yellow}Error: ${body.message}${colors.reset}`);
        }
      }

      if (details.length > 0) {
        logLine += `\n    ${details.join(" | ")}`;
      }
    }

    // Output the log
    // eslint-disable-next-line no-console
    console.log(logLine);

    // Log stack trace for 500 errors in development
    if (status >= 500 && isDevelopment) {
      const body = loggableRes._body as Record<string, unknown> | undefined;
      if (body?.stack) {
        // eslint-disable-next-line no-console
        console.error(`${colors.red}Stack trace:${colors.reset}`);
        // eslint-disable-next-line no-console
        console.error(colors.dim + body.stack + colors.reset);
      }
    }
  });

  next();
};

// =============================================================================
// Error Logger (for use in error handling middleware)
// =============================================================================

export interface LogErrorOptions {
  error: Error;
  req: Request;
  txHash?: string;
  context?: string;
}

/**
 * Log an error with context (for use in catch blocks or error middleware)
 */
export const logError = (options: LogErrorOptions): void => {
  const { error, req, txHash, context } = options;
  const timestamp = `${colors.gray}[${getTimestamp()}]${colors.reset}`;
  const icon = "❌";

  let logLine = `${timestamp} ${icon} ${colors.red}ERROR${colors.reset}`;

  if (context) {
    logLine += ` ${colors.yellow}[${context}]${colors.reset}`;
  }

  logLine += ` ${colors.white}${req.method} ${req.originalUrl}${colors.reset}`;
  logLine += `\n    ${colors.red}${error.message}${colors.reset}`;

  if (txHash) {
    logLine += `\n    ${colors.cyan}txHash: ${txHash}${colors.reset}`;
  }

  // eslint-disable-next-line no-console
  console.error(logLine);

  if (isDevelopment && error.stack) {
    // eslint-disable-next-line no-console
    console.error(`${colors.dim}${error.stack}${colors.reset}`);
  }
};

// =============================================================================
// Blockchain Transaction Logger
// =============================================================================

export interface LogBlockchainTxOptions {
  action: string;
  txHash?: string;
  success: boolean;
  error?: string;
  userId?: string;
  points?: number;
  wasteType?: string;
}

/**
 * Log blockchain transaction events
 */
export const logBlockchainTx = (options: LogBlockchainTxOptions): void => {
  const { action, txHash, success, error, userId, points, wasteType } = options;
  const timestamp = `${colors.gray}[${getTimestamp()}]${colors.reset}`;
  const icon = success ? "⛓ " : "⛓ ❌";
  const statusColor = success ? colors.green : colors.red;
  const status = success ? "SUCCESS" : "FAILED";

  let logLine = `${timestamp} ${icon} ${colors.magenta}[BLOCKCHAIN]${colors.reset}`;
  logLine += ` ${colors.white}${action}${colors.reset}`;
  logLine += ` ${statusColor}${status}${colors.reset}`;

  const details: string[] = [];

  if (txHash) {
    const shortHash = `${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 6)}`;
    details.push(`txHash: ${shortHash}`);
  }

  if (userId) {
    details.push(`user: ${truncateId(userId)}`);
  }

  if (points !== undefined) {
    details.push(`points: ${points}`);
  }

  if (wasteType) {
    details.push(`type: ${wasteType}`);
  }

  if (error) {
    details.push(`${colors.red}error: ${error}${colors.reset}`);
  }

  if (details.length > 0) {
    logLine += `\n    ${colors.gray}${details.join(" | ")}${colors.reset}`;
  }

  // eslint-disable-next-line no-console
  console.log(logLine);
};

// =============================================================================
// Startup Banner
// =============================================================================

/**
 * Log a startup banner with server info
 */
export const logStartup = (port: number): void => {
  const divider = colors.cyan + "═".repeat(50) + colors.reset;

  // eslint-disable-next-line no-console
  console.log("\n" + divider);
  // eslint-disable-next-line no-console
  console.log(
    `${colors.green}${colors.bright}  ♻  Waste Recycling Backend Server${colors.reset}`
  );
  // eslint-disable-next-line no-console
  console.log(divider);
  // eslint-disable-next-line no-console
  console.log(`  ${colors.white}Port:${colors.reset}        ${colors.cyan}${port}${colors.reset}`);
  // eslint-disable-next-line no-console
  console.log(
    `  ${colors.white}Mode:${colors.reset}        ${isDevelopment ? colors.yellow + "development" : colors.green + "production"}${colors.reset}`
  );
  // eslint-disable-next-line no-console
  console.log(
    `  ${colors.white}Time:${colors.reset}        ${colors.gray}${getTimestamp()}${colors.reset}`
  );
  // eslint-disable-next-line no-console
  console.log(divider + "\n");
};

export default loggerMiddleware;
