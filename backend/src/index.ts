import "./config/env";
import cors from "cors";
import express, { NextFunction, Request, Response } from "express";
import mongoose from "mongoose";
import cookieParser from "cookie-parser";
import path from "path";
import recycleRoutes from "./routes/recycleRoutes";
import userRoutes from "./routes/userRoutes";
import authRoutes from "./routes/authRoutes";
import wasteRoutes from "./routes/wasteRoutes";
import rewardsRoutes from "./routes/rewardsRoutes";
import { getBlockchainHealth } from "./services/blockchainServiceV2";
import { getAiHealth } from "./services/aiService";
import { loggerMiddleware, logStartup } from "./middleware/logger";

const app = express();

app.use(cors());
app.use(express.json());
// app.use(cookieParser());

// Request/Response logging middleware (must be before routes)
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

// Multer file-filter errors → 415; multer limit errors → 400; others → 500
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  // Multer error: invalid file type from fileFilter
  if (
    err.message &&
    err.message.toLowerCase().includes("invalid file type")
  ) {
    return res.status(415).json({ message: err.message });
  }
  // Multer error: file too large or other multer limits
  if ((err as { code?: string }).code === "LIMIT_FILE_SIZE") {
    return res.status(400).json({ message: "File too large. Maximum size is 10 MB." });
  }

  const status = (err as { status?: number }).status ?? 500;
  res.status(status).json({
    message: err.message || "Internal server error",
  });
});

const port = process.env.PORT ? Number(process.env.PORT) : 5000;

const startServer = async () => {
  const mongoUri = process.env.MONGODB_URI;
  if (!mongoUri) {
    throw new Error("MONGODB_URI is not set");
  }

  await mongoose.connect(mongoUri);
  app.listen(port, () => {
    logStartup(port);
  });
};

startServer().catch((error) => {
  // eslint-disable-next-line no-console
  console.error("Failed to start server:", error);
  process.exit(1);
});
