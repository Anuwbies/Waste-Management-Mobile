/**
 * AdminAuditEvent — Denormalized read-model for the admin audit trail
 * ====================================================================
 * One document per auditable action (scan, recycle, redeem, wallet, auth).
 * Populated by controller hooks whenever those events happen, **and** by
 * a one-time back-fill script if needed.
 */

import { Document, Schema, model, Types } from "mongoose";

export type AuditActivityType =
  | "scan"
  | "recycle"
  | "redeem"
  | "wallet_create"
  | "wallet_topup"
  | "wallet_withdraw"
  | "login"
  | "register"
  | "admin_action"
  | "integrity";

export type AuditStatus =
  | "approved"
  | "denied"
  | "pending"
  | "confirmed"
  | "failed"
  | "duplicate"
  | "error";

export interface IAdminAuditEvent extends Document {
  /** The originating user */
  userId: Types.ObjectId;
  userEmail: string;
  userName: string;
  walletAddress?: string;

  /** Event classification */
  activityType: AuditActivityType;
  status: AuditStatus;

  /** Waste / AI */
  wasteType?: string;
  confidence?: number;
  rawLabel?: string;
  modelVersion?: string;
  imageUrl?: string;
  imageHash?: string;
  rawPredictions?: Record<string, number>;

  /** Reward */
  points?: number;
  rewardCalculation?: string;
  bonusApplied?: boolean;

  /** Blockchain */
  txHash?: string;
  blockNumber?: number;
  chainId?: number;
  contractAddress?: string;
  gasUsed?: string;
  txStatus?: "success" | "failed" | "pending";
  eventHash?: string;

  /** Source references (so we can join back) */
  classificationId?: Types.ObjectId;
  recyclingEventId?: Types.ObjectId;
  rewardTransactionId?: Types.ObjectId;

  /** Admin annotations */
  adminNotes?: string;
  flagged: boolean;

  /** Metadata bag */
  metadata?: Record<string, unknown>;

  createdAt: Date;
  updatedAt: Date;
}

const adminAuditEventSchema = new Schema<IAdminAuditEvent>(
  {
    userId: { type: Schema.Types.ObjectId, ref: "User", required: true },
    userEmail: { type: String, required: true },
    userName: { type: String, default: "" },
    walletAddress: { type: String },

    activityType: {
      type: String,
      enum: [
        "scan",
        "recycle",
        "redeem",
        "wallet_create",
        "wallet_topup",
        "wallet_withdraw",
        "login",
        "register",
        "admin_action",
        "integrity",
      ],
      required: true,
    },
    status: {
      type: String,
      enum: ["approved", "denied", "pending", "confirmed", "failed", "duplicate", "error"],
      default: "pending",
    },

    wasteType: { type: String },
    confidence: { type: Number },
    rawLabel: { type: String },
    modelVersion: { type: String },
    imageUrl: { type: String },
    imageHash: { type: String },
    rawPredictions: { type: Schema.Types.Mixed },

    points: { type: Number },
    rewardCalculation: { type: String },
    bonusApplied: { type: Boolean },

    txHash: { type: String },
    blockNumber: { type: Number },
    chainId: { type: Number },
    contractAddress: { type: String },
    gasUsed: { type: String },
    txStatus: { type: String, enum: ["success", "failed", "pending"] },
    eventHash: { type: String },

    classificationId: { type: Schema.Types.ObjectId, ref: "WasteClassification" },
    recyclingEventId: { type: Schema.Types.ObjectId, ref: "RecyclingEvent" },
    rewardTransactionId: { type: Schema.Types.ObjectId, ref: "RewardTransaction" },

    adminNotes: { type: String, default: "" },
    flagged: { type: Boolean, default: false },

    metadata: { type: Schema.Types.Mixed },
  },
  { timestamps: true },
);

/* ── Indexes ── */
adminAuditEventSchema.index({ createdAt: -1 });
adminAuditEventSchema.index({ userId: 1, createdAt: -1 });
adminAuditEventSchema.index({ activityType: 1, createdAt: -1 });
adminAuditEventSchema.index({ status: 1 });
adminAuditEventSchema.index({ wasteType: 1 });
adminAuditEventSchema.index({ flagged: 1 });
adminAuditEventSchema.index({ txHash: 1 }, { sparse: true });
adminAuditEventSchema.index({ eventHash: 1 }, { sparse: true });
adminAuditEventSchema.index({
  userEmail: "text",
  walletAddress: "text",
  txHash: "text",
  eventHash: "text",
});

const AdminAuditEvent = model<IAdminAuditEvent>(
  "AdminAuditEvent",
  adminAuditEventSchema,
);

export default AdminAuditEvent;
