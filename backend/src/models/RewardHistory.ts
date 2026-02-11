import { Document, Schema, model, Types } from "mongoose";

export type RewardType = "recycling" | "classification" | "bonus" | "redemption";

export interface IRewardHistory extends Document {
  userId: Types.ObjectId;
  type: RewardType;
  points: number;
  description: string;
  referenceId?: Types.ObjectId;
  txHash?: string;
  createdAt: Date;
  updatedAt: Date;
}

const rewardHistorySchema = new Schema<IRewardHistory>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    type: {
      type: String,
      enum: ["recycling", "classification", "bonus", "redemption"],
      required: true,
    },
    points: { type: Number, required: true },
    description: { type: String, required: true },
    referenceId: { type: Schema.Types.ObjectId },
    txHash: { type: String },
  },
  { timestamps: true }
);

rewardHistorySchema.index({ userId: 1, createdAt: -1 });

const RewardHistory = model<IRewardHistory>("RewardHistory", rewardHistorySchema);

export default RewardHistory;
