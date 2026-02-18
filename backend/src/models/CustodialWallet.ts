import { Document, Schema, model, Types } from "mongoose";

export interface ICustodialWallet extends Document {
  userId: Types.ObjectId;
  address: string;
  encryptedPrivateKey?: string;
  derivationIndex: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const custodialWalletSchema = new Schema<ICustodialWallet>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    address: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
    },
    encryptedPrivateKey: {
      type: String,
      select: false, // never returned by default queries
    },
    derivationIndex: {
      type: Number,
      required: true,
      unique: true,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  { timestamps: true }
);

// Find the next available derivation index
custodialWalletSchema.statics.getNextDerivationIndex = async function (): Promise<number> {
  const lastWallet = await this.findOne().sort({ derivationIndex: -1 }).lean();
  return lastWallet ? lastWallet.derivationIndex + 1 : 0;
};

const CustodialWallet = model<ICustodialWallet>(
  "CustodialWallet",
  custodialWalletSchema
);

export default CustodialWallet;
