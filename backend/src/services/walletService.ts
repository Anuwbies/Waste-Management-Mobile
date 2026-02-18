import crypto from "crypto";
import CustodialWallet, {
  ICustodialWallet,
} from "../models/CustodialWallet";
import User from "../models/User";
import { deriveCustodialWallet } from "./blockchainServiceV2";

// ---------------------------------------------------------------------------
// Encryption helpers – AES-256-GCM for private key at rest
// ---------------------------------------------------------------------------
const ALGORITHM = "aes-256-gcm";

/**
 * Derive a 32-byte encryption key from HD_WALLET_ENCRYPTION_KEY or
 * fall back to a SHA-256 hash of HD_WALLET_MNEMONIC (so encryption
 * works out-of-the-box in dev without an extra env var).
 */
const getEncryptionKey = (): Buffer => {
  const raw =
    process.env.HD_WALLET_ENCRYPTION_KEY ?? process.env.HD_WALLET_MNEMONIC;
  if (!raw) {
    throw new Error(
      "HD_WALLET_ENCRYPTION_KEY or HD_WALLET_MNEMONIC must be set to encrypt custodial keys",
    );
  }
  return crypto.createHash("sha256").update(raw).digest();
};

const encrypt = (plaintext: string): string => {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const encrypted = Buffer.concat([
    cipher.update(plaintext, "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  // Store as   iv:tag:ciphertext   (all hex)
  return `${iv.toString("hex")}:${tag.toString("hex")}:${encrypted.toString("hex")}`;
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

export interface WalletResult {
  address: string;
  isNew: boolean;
}

/**
 * Ensure a custodial wallet exists for the given user.
 *
 * 1. If one already exists → return it.
 * 2. Otherwise → derive next HD wallet, store encrypted private key, update
 *    user.walletAddress, and return the new record.
 *
 * This is idempotent and safe to call from any auth endpoint.
 */
export const ensureCustodialWallet = async (
  userId: string,
): Promise<WalletResult> => {
  // 1. Fast path – wallet already exists
  const existing = await CustodialWallet.findOne({ userId });
  if (existing) {
    // Also make sure the User document has the address cached
    await _syncUserWalletAddress(userId, existing.address);
    return { address: existing.address, isNew: false };
  }

  // 2. Derive next wallet (atomic-ish via unique index on derivationIndex)
  const lastWallet = await CustodialWallet.findOne().sort({
    derivationIndex: -1,
  });
  const nextIndex = lastWallet ? lastWallet.derivationIndex + 1 : 0;

  const { address, privateKey } = deriveCustodialWallet(nextIndex);

  // Encrypt private key before persisting
  let encryptedPrivateKey: string | undefined;
  try {
    encryptedPrivateKey = encrypt(privateKey);
  } catch {
    // If encryption env is missing, still create the wallet (keys are
    // re-derivable from mnemonic + index), just skip encrypted storage.
  }

  const wallet = await CustodialWallet.create({
    userId,
    address,
    derivationIndex: nextIndex,
    ...(encryptedPrivateKey ? { encryptedPrivateKey } : {}),
  });

  // Keep user.walletAddress in sync
  await _syncUserWalletAddress(userId, wallet.address);

  return { address: wallet.address, isNew: true };
};

// ---------------------------------------------------------------------------
// Internal helper
// ---------------------------------------------------------------------------

/**
 * Ensure user.walletAddress matches the custodial wallet address.
 * Only writes to DB when there's an actual mismatch.
 */
const _syncUserWalletAddress = async (
  userId: string,
  address: string,
): Promise<void> => {
  await User.updateOne(
    { _id: userId, walletAddress: { $ne: address } },
    { $set: { walletAddress: address } },
  );
};
