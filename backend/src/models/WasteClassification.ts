import { Document, Schema, model, Types } from "mongoose";

export interface IWasteClassification extends Document {
  userId: Types.ObjectId;
  imageUrl: string;
  wasteType: string;
  confidence: number;
  rewardPoints: number;
  createdAt: Date;
  updatedAt: Date;
}

const wasteClassificationSchema = new Schema<IWasteClassification>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    imageUrl: { type: String, required: true },
    wasteType: { type: String, required: true },
    confidence: { type: Number, default: 0 },
    rewardPoints: { type: Number, default: 0 },
  },
  { timestamps: true }
);

wasteClassificationSchema.index({ userId: 1, createdAt: -1 });

const WasteClassification = model<IWasteClassification>(
  "WasteClassification",
  wasteClassificationSchema
);

export default WasteClassification;
