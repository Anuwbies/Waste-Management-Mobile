import "./config/env";
import cors from "cors";
import express, { NextFunction, Request, Response } from "express";
import mongoose from "mongoose";
import path from "path";
import recycleRoutes from "./routes/recycleRoutes";
import userRoutes from "./routes/userRoutes";
import authRoutes from "./routes/authRoutes";
import wasteRoutes from "./routes/wasteRoutes";
import rewardsRoutes from "./routes/rewardsRoutes";
import { getBlockchainHealth } from "./services/blockchainServiceV2";
import { loggerMiddleware, logStartup } from "./middleware/logger";

const app = express();

app.use(cors());
app.use(express.json());

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

// API Routes
app.use("/auth", authRoutes);
app.use("/waste", wasteRoutes);
app.use("/rewards", rewardsRoutes);
app.use("/recycle", recycleRoutes);
app.use("/user", userRoutes);

app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
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
