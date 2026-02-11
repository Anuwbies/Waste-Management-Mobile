import { Document, Schema, model, Types } from "mongoose";

export interface IRecyclingLog extends Document {
  userId: Types.ObjectId;
  wasteType: string;
  quantity: number;
  rewardPoints: number;
  txHash?: string;
  createdAt: Date;
  updatedAt: Date;
}

const recyclingLogSchema = new Schema<IRecyclingLog>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    wasteType: { type: String, required: true },
    quantity: { type: Number, default: 1 },
    rewardPoints: { type: Number, required: true },
    txHash: { type: String },
  },
  { timestamps: true }
);

recyclingLogSchema.index({ userId: 1, createdAt: -1 });

const RecyclingLog = model<IRecyclingLog>("RecyclingLog", recyclingLogSchema);

export default RecyclingLog;
