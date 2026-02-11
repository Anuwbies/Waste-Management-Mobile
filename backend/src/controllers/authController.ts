import { Request, Response, NextFunction } from "express";
import bcrypt from "bcryptjs";
import { OAuth2Client } from "google-auth-library";
import User from "../models/User";
import { generateToken, AuthRequest } from "../middleware/auth";

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

// POST /auth/register
export const register = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password, name, walletAddress } = req.body as {
      email?: string;
      password?: string;
      name?: string;
      walletAddress?: string;
    };
    console.log(email)
    if (!email || !password || !name) {
      return res.status(400).json({
        message: "Email, password, and name are required",
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({ message: "Email already registered" });
    }

    // Hash password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create user
    const user = await User.create({
      email,
      passwordHash,
      name,
      walletAddress: walletAddress || "",
      totalRewards: 0,
    });

    return res.status(201).json({
      message: "User registered successfully",
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
      },
    });
  } catch (error) {
    return next(error);
  }
};

// POST /auth/login
export const login = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { email, password } = req.body as {
      email?: string;
      password?: string;
    };

    if (!email || !password) {
      return res.status(400).json({
        message: "Email and password are required",
      });
    }

    // Find user
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({ message: "Invalid email or password" });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.passwordHash);
    if (!isValidPassword) {
      return res.status(401).json({ message: "Invalid email or password" });
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
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        photoUrl: user.photoUrl,
        walletAddress: user.walletAddress,
        totalRewards: user.totalRewards,
      },
    });
  } catch (error) {
    return next(error);
  }
};

// POST /auth/google
export const googleLogin = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  try {
    const { idToken } = req.body as { idToken?: string };

    if (!idToken) {
      return res.status(400).json({ message: "Google ID token is required" });
    }

    // Verify Google token
    const ticket = await googleClient.verifyIdToken({
      idToken,
      audience: process.env.GOOGLE_CLIENT_ID,
    });

    const payload = ticket.getPayload();
    if (!payload || !payload.email) {
      return res.status(401).json({ message: "Invalid Google token" });
    }

    const { email, name, picture, sub: googleId } = payload;

    // Find or create user
    let user = await User.findOne({ email });

    if (!user) {
      user = await User.create({
        email,
        name: name || "Google User",
        googleId,
        photoUrl: picture,
        walletAddress: "",
        totalRewards: 0,
        passwordHash: "", // No password for Google users
      });
    } else {
      // Update Google info if needed
      if (!user.googleId) {
        user.googleId = googleId;
      }
      if (picture && !user.photoUrl) {
        user.photoUrl = picture;
      }
      await user.save();
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
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        photoUrl: user.photoUrl,
        walletAddress: user.walletAddress,
        totalRewards: user.totalRewards,
      },
    });
  } catch (error) {
    return next(error);
  }
};

// GET /auth/me
export const getCurrentUser = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
) => {
  try {
    const userId = req.userId;

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ message: "User not found" });
    }

    return res.status(200).json({
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        photoUrl: user.photoUrl,
        walletAddress: user.walletAddress,
        totalRewards: user.totalRewards,
        createdAt: user.createdAt,
      },
    });
  } catch (error) {
    return next(error);
  }
};

// PUT /auth/me
export const updateCurrentUser = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
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
      user: {
        id: user._id,
        email: user.email,
        name: user.name,
        photoUrl: user.photoUrl,
        walletAddress: user.walletAddress,
        totalRewards: user.totalRewards,
      },
    });
  } catch (error) {
    return next(error);
  }
};
