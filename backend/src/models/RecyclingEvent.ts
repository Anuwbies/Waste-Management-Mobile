import { Document, Schema, model, Types } from "mongoose";

export type RecyclingEventStatus =
  | "pending"
  | "confirmed"
  | "failed"
  | "duplicate";

export interface IRecyclingEvent extends Document {
  eventHash: string;
  userId: Types.ObjectId;
  userWallet: string;
  wasteType: string;
  imageHash?: string;
  aiConfidence?: number;
  rewardPoints: number;
  status: RecyclingEventStatus;
  txHash?: string;
  chainId?: number;
  retryCount: number;
  errorMessage?: string;
  metadata?: {
    deviceId?: string;
    location?: {
      lat: number;
      lng: number;
    };
    scanTimestamp?: Date;
  };
  createdAt: Date;
  updatedAt: Date;
  confirmedAt?: Date;
}

const recyclingEventSchema = new Schema<IRecyclingEvent>(
  {
    eventHash: {
      type: String,
      required: true,
      unique: true,
    },
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    userWallet: {
      type: String,
      required: true,
    },
    wasteType: {
      type: String,
      required: true,
    },
    imageHash: {
      type: String,
    },
    aiConfidence: {
      type: Number,
      min: 0,
      max: 1,
    },
    rewardPoints: {
      type: Number,
      required: true,
      min: 0,
    },
    status: {
      type: String,
      enum: ["pending", "confirmed", "failed", "duplicate"],
      default: "pending",
    },
    txHash: {
      type: String,
    },
    chainId: {
      type: Number,
    },
    retryCount: {
      type: Number,
      default: 0,
    },
    errorMessage: {
      type: String,
    },
    metadata: {
      deviceId: String,
      location: {
        lat: Number,
        lng: Number,
      },
      scanTimestamp: Date,
    },
    confirmedAt: {
      type: Date,
    },
  },
  { timestamps: true }
);

// Compound indices for common queries
recyclingEventSchema.index({ userId: 1, createdAt: -1 });
recyclingEventSchema.index({ status: 1, createdAt: 1 }); // For retry queue
recyclingEventSchema.index({ txHash: 1 }, { sparse: true });

const RecyclingEvent = model<IRecyclingEvent>(
  "RecyclingEvent",
  recyclingEventSchema
);

export default RecyclingEvent;
