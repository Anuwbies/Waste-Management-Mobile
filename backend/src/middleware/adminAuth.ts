/**
 * Admin Authentication & Authorization Middleware
 * ================================================
 * Reuses the existing JWT infrastructure but adds an admin‐role gate.
 *
 * Usage:
 *   router.use(adminAuth);          // verify JWT + attach user
 *   router.use(adminOnly);          // check isAdmin flag
 *   router.get("/dashboard", …);
 */

import { Response, NextFunction } from "express";
import { AuthRequest, verifyToken } from "./auth";
import User from "../models/User";
import { logger } from "../config/logger";

/**
 * Verify Bearer token and attach `req.userId` / `req.user`.
 * Identical to the existing `authMiddleware` but kept separate
 * so the admin pipeline is self-contained.
 */
export const adminAuth = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({ message: "No token provided" });
    }

    const token = authHeader.split(" ")[1];
    const decoded = verifyToken(token);

    req.userId = decoded.userId;
    req.user = {
      id: decoded.userId,
      email: decoded.email,
      name: decoded.name,
    };

    return next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
};

/**
 * Gate: only users whose DB record carries `role === "admin"` may proceed.
 * Must run **after** `adminAuth`.
 */
export const adminOnly = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) => {
  try {
    if (!req.userId) {
      return res.status(401).json({ message: "Authentication required" });
    }

    const user = await User.findById(req.userId).select("role isAdmin").lean();
    if (!user) {
      return res.status(401).json({ message: "User not found" });
    }

    // Support both `role` field and `isAdmin` flag
    const isAdmin =
      (user as Record<string, unknown>).role === "admin" ||
      (user as Record<string, unknown>).role === "superadmin" ||
      (user as Record<string, unknown>).isAdmin === true;

    if (!isAdmin) {
      logger.warn(`Non-admin access attempt by userId=${req.userId}`);
      return res.status(403).json({ message: "Admin privileges required" });
    }

    return next();
  } catch (error) {
    logger.error("adminOnly middleware error:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};
