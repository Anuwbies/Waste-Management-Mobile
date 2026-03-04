import { Document, Schema, model } from "mongoose";

export interface IUser extends Document {
  name: string;
  email: string;
  passwordHash: string;
  googleId?: string;
  photoUrl?: string;
  emailVerified: boolean;
  walletAddress: string;
  totalRewards: number;

  // Admin / role fields
  role: "user" | "admin" | "superadmin";
  isAdmin: boolean;

  // Password-reset OTP fields
  passwordResetOtpHash?: string;
  passwordResetOtpExpiresAt?: Date;
  passwordResetAttempts: number;
  passwordResetTokenHash?: string;

  // Login-attempt tracking
  loginAttempts: number;
  loginLockUntil?: Date;

  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    passwordHash: { type: String, default: "" },
    googleId: { type: String },
    photoUrl: { type: String },
    emailVerified: { type: Boolean, default: false },
    walletAddress: { type: String, default: "" },
    totalRewards: { type: Number, default: 0 },

    // Admin / role fields
    role: {
      type: String,
      enum: ["user", "admin", "superadmin"],
      default: "user",
    },
    isAdmin: { type: Boolean, default: false },

    // Password-reset OTP
    passwordResetOtpHash: { type: String },
    passwordResetOtpExpiresAt: { type: Date },
    passwordResetAttempts: { type: Number, default: 0 },
    passwordResetTokenHash: { type: String },

    // Login-attempt tracking
    loginAttempts: { type: Number, default: 0 },
    loginLockUntil: { type: Date },
  },
  { timestamps: true }
);

// email index is auto-created by unique: true
userSchema.index({ googleId: 1 }, { unique: true, sparse: true });

const User = model<IUser>("User", userSchema);

export default User;
