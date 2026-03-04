/**
 * Admin Auth Controller
 * =====================
 * POST /admin/login
 */

import { Request, Response } from "express";
import bcrypt from "bcryptjs";
import { generateToken } from "../middleware/auth";
import User from "../models/User";
import { logger } from "../config/logger";

export const adminLogin = async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Email and password are required",
      });
    }

    // Find user — include passwordHash + role/isAdmin
    const user = await User.findOne({ email: email.toLowerCase().trim() })
      .select("+passwordHash +role +isAdmin")
      .lean();

    if (!user) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    // Verify password
    if (!user.passwordHash) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    // Check admin privilege
    const record = user as Record<string, unknown>;
    const isAdmin =
      record.role === "admin" ||
      record.role === "superadmin" ||
      record.isAdmin === true;

    if (!isAdmin) {
      logger.warn(`Non-admin login attempt: ${email}`);
      return res.status(403).json({ message: "Admin privileges required" });
    }

    // Generate token (8 h expiry for admin sessions)
    const token = generateToken({
      userId: (user._id as unknown as { toString: () => string }).toString(),
      email: user.email,
      name: user.name,
    });

    // Response shape matches frontend AuthResponse
    return res.json({
      token,
      user: {
        id: (user._id as unknown as { toString: () => string }).toString(),
        email: user.email,
        name: user.name,
        role: (record.role as string) ?? "admin",
      },
    });
  } catch (error) {
    logger.error("adminLogin error:", error);
    return res.status(500).json({ message: "Internal server error" });
  }
};

export const adminLogout = async (_req: Request, res: Response) => {
  // Stateless JWT — nothing to invalidate server-side.
  // Frontend clears token from localStorage.
  return res.json({ message: "Logged out" });
};
