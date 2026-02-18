import { Request, Response, NextFunction } from "express";
import crypto from "crypto";
import bcrypt from "bcryptjs";
import { OAuth2Client } from "google-auth-library";
import User from "../models/User";
import CustodialWallet from "../models/CustodialWallet";
import { generateToken, AuthRequest } from "../middleware/auth";
import { validatePasswordPolicy } from "../validators/passwordPolicy";
import { sendPasswordResetOtp } from "../services/emailService";
import { ensureCustodialWallet } from "../services/walletService";

// ---------------------------------------------------------------------------
// Google OAuth2 client (supports multiple client IDs for Android/iOS/web)
// ---------------------------------------------------------------------------
const googleClientIds: string[] = (() => {
  const ids: string[] = [];
  if (process.env.GOOGLE_CLIENT_ID) ids.push(process.env.GOOGLE_CLIENT_ID);
  if (process.env.GOOGLE_CLIENT_IDS) {
    ids.push(
      ...process.env.GOOGLE_CLIENT_IDS.split(",").map((s) => s.trim()).filter(Boolean),
    );
  }
  return ids;
})();

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const BCRYPT_ROUNDS = 12;
const OTP_EXPIRY_MINUTES = 10;
const MAX_OTP_ATTEMPTS = 5;
const LOGIN_MAX_ATTEMPTS = 5;
const LOGIN_LOCK_MINUTES = 10;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Generate a cryptographically secure 6-digit OTP */
const generateOtp = (): string => {
  const num = crypto.randomInt(0, 1_000_000);
  return String(num).padStart(6, "0");
};

/** Hash an OTP using SHA-256 (fast, suitable for short-lived secrets) */
const hashOtp = (otp: string): string =>
  crypto.createHash("sha256").update(otp).digest("hex");

/** Create a custodial wallet for a newly-created user (best-effort) */
const ensureWallet = async (
  userId: string,
): Promise<string | undefined> => {
  try {
    const { address } = await ensureCustodialWallet(userId);
    return address;
  } catch {
    // Non-critical – wallet can be created later via /wallet/ensure
    return undefined;
  }
};

/** Standard user payload returned in responses */
const userPayload = (user: InstanceType<typeof User>, walletAddress?: string) => ({
  id: user._id,
  email: user.email,
  name: user.name,
  photoUrl: user.photoUrl,
  walletAddress: walletAddress ?? user.walletAddress,
  totalRewards: user.totalRewards,
});

// =========================================================================
// POST /auth/register
// =========================================================================
export const register = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { email, password, name, walletAddress } = req.body as {
      email?: string;
      password?: string;
      name?: string;
      walletAddress?: string;
    };

    if (!email || !password || !name) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Email, password, and name are required",
      });
    }

    // Enforce strong password policy
    const policy = validatePasswordPolicy(password, email);
    if (!policy.valid) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Password does not meet security requirements",
        details: policy.errors,
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email: email.toLowerCase().trim() });
    if (existingUser) {
      return res.status(409).json({
        code: "EMAIL_TAKEN",
        message: "Email already registered",
      });
    }

    // Hash password
    const passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);

    // Create user
    const user = await User.create({
      email: email.toLowerCase().trim(),
      passwordHash,
      name,
      walletAddress: walletAddress || "",
      totalRewards: 0,
    });

    // Attempt to create custodial wallet
    const wallet = await ensureWallet(user._id.toString());

    if (wallet) {
      user.walletAddress = wallet;
      await user.save();
    }

    return res.status(201).json({
      message: "User registered successfully",
      token: generateToken({
        userId: user._id.toString(),
        email: user.email,
        name: user.name,
      }),
      user: userPayload(user, wallet),
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// POST /auth/login
// =========================================================================
export const login = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { email, password } = req.body as {
      email?: string;
      password?: string;
    };

    if (!email || !password) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Email and password are required",
      });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Find user
    const user = await User.findOne({ email: normalizedEmail });

    // Always return the same error for user-not-found and wrong-password
    if (!user) {
      // Spend roughly the same time as a bcrypt compare to avoid timing leaks
      await bcrypt.hash("timing-safe-dummy", BCRYPT_ROUNDS);
      return res.status(401).json({
        code: "INVALID_CREDENTIALS",
        message: "Invalid email or password",
      });
    }

    // Account locked?
    if (user.loginLockUntil && user.loginLockUntil > new Date()) {
      return res.status(429).json({
        code: "TOO_MANY_ATTEMPTS",
        message: "Account temporarily locked. Please try again later.",
      });
    }

    // Verify password
    if (!user.passwordHash) {
      // User registered via Google only – no password set
      return res.status(401).json({
        code: "INVALID_CREDENTIALS",
        message: "Invalid email or password",
      });
    }

    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      // Increment login attempts
      user.loginAttempts = (user.loginAttempts || 0) + 1;
      if (user.loginAttempts >= LOGIN_MAX_ATTEMPTS) {
        user.loginLockUntil = new Date(
          Date.now() + LOGIN_LOCK_MINUTES * 60 * 1000,
        );
      }
      await user.save();

      return res.status(401).json({
        code: "INVALID_CREDENTIALS",
        message: "Invalid email or password",
      });
    }

    // Reset login attempts on success
    if (user.loginAttempts > 0 || user.loginLockUntil) {
      user.loginAttempts = 0;
      user.loginLockUntil = undefined;
      await user.save();
    }

    // Ensure custodial wallet exists (migration safety for legacy users)
    const wallet = await ensureWallet(user._id.toString());
    if (wallet && user.walletAddress !== wallet) {
      user.walletAddress = wallet;
      await user.save();
    }

    // Generate JWT
    const token = generateToken({
      userId: user._id.toString(),
      email: user.email,
      name: user.name,
    });

    return res.status(200).json({
      message: "Login successful",
      token,
      user: userPayload(user, wallet),
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// POST /auth/google  –  Google Fast Auth (ID-token verification)
// =========================================================================
export const googleLogin = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { idToken } = req.body as { idToken?: string };

    if (!idToken) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Google ID token is required",
      });
    }

    // Verify Google token
    let payload;
    try {
      const ticket = await googleClient.verifyIdToken({
        idToken,
        audience: googleClientIds.length > 0 ? googleClientIds : undefined,
      });
      payload = ticket.getPayload();
    } catch {
      return res.status(401).json({
        code: "INVALID_CREDENTIALS",
        message: "Invalid or expired Google token",
      });
    }

    if (!payload || !payload.email) {
      return res.status(401).json({
        code: "INVALID_CREDENTIALS",
        message: "Invalid Google token payload",
      });
    }

    const { email, name, picture, sub: googleId } = payload;
    const normalizedEmail = email.toLowerCase().trim();

    // Find by googleId first, then by email
    let user = await User.findOne({
      $or: [{ googleId }, { email: normalizedEmail }],
    });

    if (user) {
      // Link googleId if missing (email-matched account)
      if (!user.googleId) {
        user.googleId = googleId;
      }
      if (picture && !user.photoUrl) {
        user.photoUrl = picture;
      }
      if (!user.emailVerified) {
        user.emailVerified = true;
      }
      await user.save();

      // Ensure custodial wallet for existing users (migration safety)
      const wallet = await ensureWallet(user._id.toString());
      if (wallet && user.walletAddress !== wallet) {
        user.walletAddress = wallet;
        await user.save();
      }
    } else {
      // Create new user
      user = await User.create({
        email: normalizedEmail,
        name: name || "Google User",
        googleId,
        photoUrl: picture,
        emailVerified: true,
        walletAddress: "",
        totalRewards: 0,
        passwordHash: "", // No password for Google-only users
      });

      // Create custodial wallet for new user
      const wallet = await ensureWallet(user._id.toString());
      if (wallet) {
        user.walletAddress = wallet;
        await user.save();
      }
    }

    // Generate JWT
    const token = generateToken({
      userId: user._id.toString(),
      email: user.email,
      name: user.name,
    });

    return res.status(200).json({
      message: "Google login successful",
      token,
      user: userPayload(user),
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// POST /auth/forgot-password
// =========================================================================
export const forgotPassword = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  // Always return the same generic response regardless of whether
  // the email exists (prevents email enumeration).
  const genericMessage = "If an account with that email exists, a password reset code has been sent.";

  try {
    const { email } = req.body as { email?: string };

    if (!email) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Email is required",
      });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      // Do not reveal that the email does not exist
      return res.status(200).json({ message: genericMessage });
    }

    // Generate OTP
    const otp = generateOtp();
    const otpHash = hashOtp(otp);

    user.passwordResetOtpHash = otpHash;
    user.passwordResetOtpExpiresAt = new Date(
      Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000,
    );
    user.passwordResetAttempts = 0;
    user.passwordResetTokenHash = undefined;
    await user.save();

    // Send OTP via email (or log in dev)
    await sendPasswordResetOtp(normalizedEmail, otp);

    return res.status(200).json({ message: genericMessage });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// POST /auth/verify-otp
// =========================================================================
export const verifyOtp = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { email, otp } = req.body as { email?: string; otp?: string };

    if (!email || !otp) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Email and OTP are required",
      });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user || !user.passwordResetOtpHash || !user.passwordResetOtpExpiresAt) {
      return res.status(400).json({
        code: "INVALID_OTP",
        message: "Invalid or expired OTP",
      });
    }

    // Check lockout (too many attempts)
    if (user.passwordResetAttempts >= MAX_OTP_ATTEMPTS) {
      // Clear OTP to force re-request
      user.passwordResetOtpHash = undefined;
      user.passwordResetOtpExpiresAt = undefined;
      user.passwordResetAttempts = 0;
      await user.save();

      return res.status(429).json({
        code: "TOO_MANY_ATTEMPTS",
        message: "Too many OTP attempts. Please request a new code.",
      });
    }

    // Check expiry
    if (user.passwordResetOtpExpiresAt < new Date()) {
      user.passwordResetOtpHash = undefined;
      user.passwordResetOtpExpiresAt = undefined;
      user.passwordResetAttempts = 0;
      await user.save();

      return res.status(400).json({
        code: "OTP_EXPIRED",
        message: "OTP has expired. Please request a new code.",
      });
    }

    // Verify OTP (constant-time comparison via SHA-256 digest equality)
    const candidateHash = hashOtp(otp.trim());
    if (
      !crypto.timingSafeEqual(
        Buffer.from(candidateHash, "hex"),
        Buffer.from(user.passwordResetOtpHash, "hex"),
      )
    ) {
      user.passwordResetAttempts = (user.passwordResetAttempts || 0) + 1;
      await user.save();

      return res.status(400).json({
        code: "INVALID_OTP",
        message: "Invalid or expired OTP",
      });
    }

    // OTP valid – issue a short-lived reset token
    const resetToken = crypto.randomBytes(32).toString("hex");
    user.passwordResetTokenHash = crypto
      .createHash("sha256")
      .update(resetToken)
      .digest("hex");
    // Clear OTP so it can't be reused
    user.passwordResetOtpHash = undefined;
    user.passwordResetOtpExpiresAt = undefined;
    user.passwordResetAttempts = 0;
    await user.save();

    return res.status(200).json({
      message: "OTP verified successfully",
      resetToken,
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// POST /auth/reset-password
// =========================================================================
export const resetPassword = async (
  req: Request,
  res: Response,
  next: NextFunction,
) => {
  try {
    const { email, resetToken, newPassword } = req.body as {
      email?: string;
      resetToken?: string;
      newPassword?: string;
    };

    if (!email || !resetToken || !newPassword) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Email, reset token, and new password are required",
      });
    }

    // Enforce strong password policy
    const policy = validatePasswordPolicy(newPassword, email);
    if (!policy.valid) {
      return res.status(422).json({
        code: "VALIDATION_ERROR",
        message: "Password does not meet security requirements",
        details: policy.errors,
      });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const user = await User.findOne({ email: normalizedEmail });

    if (!user || !user.passwordResetTokenHash) {
      return res.status(400).json({
        code: "INVALID_TOKEN",
        message: "Invalid or expired reset token",
      });
    }

    // Verify reset token (constant-time)
    const candidateHash = crypto
      .createHash("sha256")
      .update(resetToken)
      .digest("hex");

    if (
      !crypto.timingSafeEqual(
        Buffer.from(candidateHash, "hex"),
        Buffer.from(user.passwordResetTokenHash, "hex"),
      )
    ) {
      return res.status(400).json({
        code: "INVALID_TOKEN",
        message: "Invalid or expired reset token",
      });
    }

    // Update password
    user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);

    // Clear all reset fields
    user.passwordResetOtpHash = undefined;
    user.passwordResetOtpExpiresAt = undefined;
    user.passwordResetAttempts = 0;
    user.passwordResetTokenHash = undefined;

    // Reset login lockout
    user.loginAttempts = 0;
    user.loginLockUntil = undefined;

    await user.save();

    return res.status(200).json({
      message: "Password reset successfully",
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// GET /auth/me
// =========================================================================
export const getCurrentUser = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = req.userId;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    // Ensure custodial wallet exists (migration safety)
    const wallet = await ensureWallet(user._id.toString());
    if (wallet && user.walletAddress !== wallet) {
      user.walletAddress = wallet;
      await user.save();
    }

    return res.status(200).json({
      user: {
        ...userPayload(user, wallet),
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// PUT /auth/me
// =========================================================================
export const updateCurrentUser = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction,
) => {
  try {
    const userId = req.userId;
    const { name, walletAddress, photoUrl } = req.body as {
      name?: string;
      walletAddress?: string;
      photoUrl?: string;
    };

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    if (name) user.name = name;
    if (walletAddress !== undefined) user.walletAddress = walletAddress;
    if (photoUrl !== undefined) user.photoUrl = photoUrl;

    await user.save();

    return res.status(200).json({
      message: "User updated successfully",
      user: userPayload(user),
    });
  } catch (error) {
    return next(error);
  }
};

// =========================================================================
// POST /auth/logout
// =========================================================================
export const logout = async (
  req: AuthRequest,
  res: Response,
  _next: NextFunction,
) => {
  // Stateless JWT: nothing to invalidate server-side.
  // The client is responsible for discarding the token.
  // We log the event so it shows up in the request logger.
  return res.status(200).json({ message: "Logged out successfully" });
};
