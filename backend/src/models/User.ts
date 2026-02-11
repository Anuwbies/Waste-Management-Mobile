import { Document, Schema, model } from "mongoose";

export interface IUser extends Document {
  name: string;
  email: string;
  passwordHash: string;
  googleId?: string;
  photoUrl?: string;
  walletAddress: string;
  totalRewards: number;
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
    walletAddress: { type: String, default: "" },
    totalRewards: { type: Number, default: 0 },
  },
  { timestamps: true }
);

// email index is auto-created by unique: true
userSchema.index({ googleId: 1 }, { unique: true, sparse: true });

const User = model<IUser>("User", userSchema);

export default User;
