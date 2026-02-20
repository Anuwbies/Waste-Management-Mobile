import "./config/env";
import cors from "cors";
import express, { Request, Response } from "express";

import { createServer } from 'http';
import { connectDatabase } from './config/database';
import { logger } from './config/logger';
import { env } from './config/env';

import path from "path";
import recycleRoutes from "./routes/recycleRoutes";
import userRoutes from "./routes/userRoutes";
import authRoutes from "./routes/authRoutes";
import wasteRoutes from "./routes/wasteRoutes";
import rewardsRoutes from "./routes/rewardsRoutes";
import walletRoutes from "./routes/walletRoutes";
import { getBlockchainHealth } from "./services/blockchainServiceV2";
import { getAiHealth } from "./services/aiService";
import { loggerMiddleware, logStartup } from "./middleware/logger";
import {
  helmetMiddleware,
  corsOptions,
  requestIdMiddleware,
} from "./middleware/security";
import mongoSanitize from "express-mongo-sanitize";
import { globalLimiter } from "./middleware/rateLimit";
import { globalErrorHandler } from "./middleware/errorHandler";

// Load environment variables
logger.info('Loading environment configuration...');
logger.debug('Environment config loaded:', env.getConfig(false));

const app = express();
const server = createServer(app);
const PORT = env.server.port;

// ── Trust proxy (required behind Render / Railway / Nginx for correct req.ip)
if (process.env.DEPLOYED_BEHIND_PROXY === "true" || process.env.NODE_ENV === "production") {
  app.set("trust proxy", 1);
}

// ── Security headers ─────────────────────────────────────────────────────────
app.use(helmetMiddleware);

// ── CORS with allowlist ──────────────────────────────────────────────────────
app.use(cors(corsOptions));

// ── Body parsing with size limits ────────────────────────────────────────────
app.use(express.json({ limit: "2mb" }));
app.use(express.urlencoded({ extended: false, limit: "2mb" }));

// ── NoSQL injection guard ────────────────────────────────────────────────────
app.use(mongoSanitize());

// ── Request-ID correlation ───────────────────────────────────────────────────
app.use(requestIdMiddleware);

// ── Global rate limit (DoS safety net) ───────────────────────────────────────
app.use(globalLimiter);

// ── Request/Response logging (must be before routes) ─────────────────────────
app.use(loggerMiddleware);

// Serve uploaded files
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));

app.get("/health", (_req: Request, res: Response) => {
  res.json({ status: "ok" });
});

// GET /health/blockchain - Blockchain connectivity health check
app.get("/health/blockchain", async (_req: Request, res: Response) => {
  try {
    const health = await getBlockchainHealth();
    const statusCode = health.ok ? 200 : 503;
    res.status(statusCode).json(health);
  } catch (error) {
    res.status(500).json({
      ok: false,
      error: (error as Error).message,
    });
  }
});

// GET /health/ai - AI inference service health check
app.get("/health/ai", async (_req: Request, res: Response) => {
  const start = Date.now();
  try {
    const health = await getAiHealth();
    const latencyMs = Date.now() - start;
    const ok = health.modelLoaded === true;
    res.status(ok ? 200 : 503).json({
      ok,
      latencyMs,
      ...health,
    });
  } catch (error) {
    const latencyMs = Date.now() - start;
    res.status(503).json({
      ok: false,
      latencyMs,
      status: "unreachable",
      error: (error as Error).message,
    });
  }
});

// API Routes
app.use("/auth", authRoutes);
app.use("/waste", wasteRoutes);
app.use("/rewards", rewardsRoutes);
app.use("/recycle", recycleRoutes);
app.use("/user", userRoutes);
app.use("/wallet", walletRoutes);

// ── Global safe error handler (must be AFTER routes) ─────────────────────────
app.use(globalErrorHandler);

const startServer = async () => {
  try {
    await connectDatabase();

    server.listen(PORT, () => {
      logger.info(`🚀 Server running on port ${PORT}`);
      logger.info(`📊 Environment: ${env.server.nodeEnv}`);

      if (env.server.isDevelopment) {
        logger.debug('Development mode - additional debugging enabled');
      }
      logStartup(PORT)
    });
  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
};

// Only start server if not in test mode
if (process.env.NODE_ENV !== 'test') {
  startServer();
}

export { app };