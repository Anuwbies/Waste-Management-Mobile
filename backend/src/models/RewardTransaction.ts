import { Document, Schema, model, Types } from "mongoose";

export type RewardTransactionType = "earn" | "redeem" | "sync" | "adjustment";
export type RewardTransactionStatus =
  | "pending"
  | "submitted"
  | "confirmed"
  | "failed";

export interface IRewardTransaction extends Document {
  userId: Types.ObjectId;
  type: RewardTransactionType;
  points: number;
  eventHash?: string;
  redemptionId?: string;
  rewardType?: string; // For redemptions: "coffee_voucher", "discount_code", etc.
  txHash?: string;
  chainId?: number;
  status: RewardTransactionStatus;
  retryCount: number;
  errorMessage?: string;
  description?: string;
  createdAt: Date;
  updatedAt: Date;
  confirmedAt?: Date;
}

const rewardTransactionSchema = new Schema<IRewardTransaction>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    type: {
      type: String,
      enum: ["earn", "redeem", "sync", "adjustment"],
      required: true,
    },
    points: {
      type: Number,
      required: true,
    },
    eventHash: {
      type: String,
    },
    redemptionId: {
      type: String,
      sparse: true,
      unique: true,
    },
    rewardType: {
      type: String,
    },
    txHash: {
      type: String,
    },
    chainId: {
      type: Number,
    },
    status: {
      type: String,
      enum: ["pending", "submitted", "confirmed", "failed"],
      default: "pending",
    },
    retryCount: {
      type: Number,
      default: 0,
    },
    errorMessage: {
      type: String,
    },
    description: {
      type: String,
    },
    confirmedAt: {
      type: Date,
    },
  },
  { timestamps: true }
);

// Compound indices
rewardTransactionSchema.index({ userId: 1, createdAt: -1 });
rewardTransactionSchema.index({ status: 1, createdAt: 1 }); // For retry queue
rewardTransactionSchema.index({ txHash: 1 }, { sparse: true });
rewardTransactionSchema.index({ eventHash: 1 }, { sparse: true });

const RewardTransaction = model<IRewardTransaction>(
  "RewardTransaction",
  rewardTransactionSchema
);

export default RewardTransaction;
