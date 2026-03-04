/**
 * AdminArchive — Metadata for ZIP archive files created by admin export
 */

import { Document, Schema, model, Types } from "mongoose";

export type ArchiveStatus = "processing" | "ready" | "error";

export interface IAdminArchive extends Document {
  createdBy: Types.ObjectId;
  startDate: Date;
  endDate: Date;
  recordCount: number;
  fileSize: number;
  filePath: string;
  status: ArchiveStatus;
  errorMessage?: string;
  createdAt: Date;
  updatedAt: Date;
}

const adminArchiveSchema = new Schema<IAdminArchive>(
  {
    createdBy: { type: Schema.Types.ObjectId, ref: "User", required: true },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    recordCount: { type: Number, default: 0 },
    fileSize: { type: Number, default: 0 },
    filePath: { type: String, default: "" },
    status: {
      type: String,
      enum: ["processing", "ready", "error"],
      default: "processing",
    },
    errorMessage: { type: String },
  },
  { timestamps: true },
);

adminArchiveSchema.index({ createdBy: 1, createdAt: -1 });
adminArchiveSchema.index({ status: 1 });

const AdminArchive = model<IAdminArchive>("AdminArchive", adminArchiveSchema);

export default AdminArchive;
