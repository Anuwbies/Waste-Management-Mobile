import { Document, Schema, model, Types } from "mongoose";

export interface IWasteClassification extends Document {
  userId: Types.ObjectId;
  imageUrl: string;
  imageHash?: string;
  wasteType: string;
  confidence: number;
  rewardPoints: number;
  rawLabel?: string;
  modelVersion?: string;
  status?: string; // "approved" | "denied" | "pending"
  createdAt: Date;
  updatedAt: Date;
}

const wasteClassificationSchema = new Schema<IWasteClassification>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    imageUrl: { type: String, required: true },
    imageHash: { type: String },
    wasteType: { type: String, required: true },
    confidence: { type: Number, default: 0 },
    rewardPoints: { type: Number, default: 0 },
    rawLabel: { type: String },
    modelVersion: { type: String },
    status: { type: String, enum: ["approved", "denied", "pending"], default: "pending" },
  },
  { timestamps: true }
);

wasteClassificationSchema.index({ userId: 1, createdAt: -1 });
wasteClassificationSchema.index(
  { userId: 1, imageHash: 1 },
  { sparse: true } // only index docs that have imageHash
);

const WasteClassification = model<IWasteClassification>(
  "WasteClassification",
  wasteClassificationSchema
);

export default WasteClassification;
