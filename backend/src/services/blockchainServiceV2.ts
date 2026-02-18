import fs from "fs";
import path from "path";
import crypto from "crypto";
import {
  Contract,
  JsonRpcProvider,
  Wallet,
  HDNodeWallet,
  keccak256,
  solidityPacked,
  TransactionReceipt,
  InterfaceAbi,
} from "ethers";

// =============================================================================
// Types
// =============================================================================

type ContractArtifact = {
  abi: InterfaceAbi;
};

export enum WasteType {
  Plastic = 0,
  Paper = 1,
  Metal = 2,
  Glass = 3,
  Organic = 4,
  EWaste = 5,
  Other = 6,
}

export interface RecordRecyclingResult {
  success: boolean;
  txHash?: string;
  error?: string;
}

export interface RedeemResult {
  success: boolean;
  txHash?: string;
  error?: string;
}

export interface UserChainStats {
  balance: bigint;
  totalEarned: bigint;
  totalRedeemed: bigint;
  recordCount: bigint;
}

export interface GlobalChainStats {
  totalEvents: bigint;
  totalMinted: bigint;
  totalBurned: bigint;
}

// =============================================================================
// Configuration
// =============================================================================

const getRpcUrl = (): string => {
  return process.env.RPC_URL || process.env.RPC_URL || "http://127.0.0.1:8545";
};

const getContractAddress = (): string => {
  const address = process.env.CONTRACT_ADDRESS;
  if (!address) {
    throw new Error("CONTRACT_ADDRESS is not configured");
  }
  return address;
};

const getAbiPath = (): string => {
  return (
    process.env.CONTRACT_ABI_PATH ||
    path.resolve(
      __dirname,
      "..",
      "..",
      "..",
      "blockchain",
      "artifacts",
      "contracts",
      "RecyclingRewardsV2.sol",
      "RecyclingRewardsV2.json"
    )
  );
};

const getChainId = (): number => {
  return parseInt(process.env.CHAIN_ID || "31337", 10); // Default: Hardhat local
};

// =============================================================================
// Provider & Contract Setup
// =============================================================================

let providerInstance: JsonRpcProvider | null = null;
let contractAbi: InterfaceAbi | null = null;

const getProvider = (): JsonRpcProvider => {
  if (!providerInstance) {
    providerInstance = new JsonRpcProvider(getRpcUrl());
  }
  return providerInstance;
};

const readAbi = (): InterfaceAbi => {
  if (contractAbi) {
    return contractAbi;
  }

  const abiPath = getAbiPath();
  if (!fs.existsSync(abiPath)) {
    throw new Error(`ABI file not found at ${abiPath}. Have you compiled the contracts?`);
  }

  const json = fs.readFileSync(abiPath, "utf8");
  const artifact = JSON.parse(json) as ContractArtifact;
  contractAbi = artifact.abi;
  return contractAbi;
};

const getContract = (runner: JsonRpcProvider | Wallet): Contract => {
  const address = getContractAddress();
  const abi = readAbi();
  return new Contract(address, abi, runner);
};

// =============================================================================
// Signer Management (Service Account)
// =============================================================================

const getServiceSigner = (): Wallet => {
  const privateKey = process.env.PRIVATE_KEY || process.env.PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("PRIVATE_KEY is not configured");
  }

  const provider = getProvider();
  return new Wallet(privateKey, provider);
};

// =============================================================================
// Custodial Wallet Management (HD Wallet)
// =============================================================================

/**
 * Return the HD node at the BIP-44 account path  m/44'/60'/0'/0
 * so that child wallets can be derived with a **relative** index.
 *
 * Why not just `HDNodeWallet.fromPhrase(mnemonic)`?
 * In ethers v6 `fromPhrase` returns a node already at the *default*
 * path  m/44'/60'/0'/0/0  (depth 5).  Calling `derivePath("m/…")`
 * on a non-root node throws:
 *   "cannot derive root path for a node at non-zero depth 5"
 *
 * By supplying the explicit parent path  m/44'/60'/0'/0  we get a
 * depth-4 node from which `derivePath("0")`, `derivePath("1")`, …
 * each produce the correct child without any "m/" prefix.
 */
const HD_PARENT_PATH = "m/44'/60'/0'/0";

const getHDParentNode = (): HDNodeWallet => {
  const mnemonic = process.env.HD_WALLET_MNEMONIC;
  if (!mnemonic) {
    throw new Error("HD_WALLET_MNEMONIC is not configured for custodial wallets");
  }

  // fromPhrase(phrase, password, path) — the 3rd arg sets the derivation path.
  return HDNodeWallet.fromPhrase(mnemonic, undefined, HD_PARENT_PATH);
};

/**
 * Derive a custodial wallet for a user based on their unique index.
 * Full derivation path: m/44'/60'/0'/0/{index}
 *
 * @param index  Non-negative integer (0, 1, 2, …) — one per user, stored in
 *               CustodialWallet.derivationIndex.
 */
export const deriveCustodialWallet = (index: number): { address: string; privateKey: string } => {
  if (!Number.isInteger(index) || index < 0) {
    throw new Error(
      `deriveCustodialWallet: index must be a non-negative integer, got ${index}`,
    );
  }

  const parent = getHDParentNode();
  // Relative path from the parent node — NO "m/" prefix.
  const child = parent.derivePath(String(index));

  return {
    address: child.address.toLowerCase(),
    privateKey: child.privateKey,
  };
};

/**
 * Generate a deterministic wallet address from userId (fallback if no HD wallet)
 * This creates a predictable address without storing private keys
 */
export const generateDeterministicAddress = (userId: string): string => {
  const hash = keccak256(solidityPacked(["string", "string"], ["user-wallet", userId]));
  // Take first 20 bytes (40 hex chars after 0x) to create an address
  return "0x" + hash.slice(26);
};

// =============================================================================
// Event Hash Generation
// =============================================================================

/**
 * Generate a unique event hash for a recycling action
 * This hash is used to prevent double-claiming on-chain
 */
export const generateEventHash = (
  userId: string,
  wasteType: string | WasteType,
  timestamp: number,
  imageHash?: string
): string => {
  // Normalize wasteType to number
  const wasteTypeNum =
    typeof wasteType === "string" ? mapWasteTypeToEnum(wasteType) : wasteType;

  // Truncate timestamp to minute for some tolerance
  const truncatedTimestamp = Math.floor(timestamp / 60000) * 60000;

  const data = imageHash
    ? solidityPacked(
        ["string", "uint8", "uint256", "string"],
        [userId, wasteTypeNum, truncatedTimestamp, imageHash]
      )
    : solidityPacked(
        ["string", "uint8", "uint256"],
        [userId, wasteTypeNum, truncatedTimestamp]
      );

  return keccak256(data);
};

/**
 * Generate a unique redemption ID
 */
export const generateRedemptionId = (
  userId: string,
  rewardType: string,
  timestamp: number
): string => {
  const data = solidityPacked(
    ["string", "string", "uint256"],
    [userId, rewardType, timestamp]
  );
  return keccak256(data);
};

/**
 * Compute SHA-256 hash of image data
 */
export const computeImageHash = (imageBuffer: Buffer): string => {
  return "0x" + crypto.createHash("sha256").update(imageBuffer).digest("hex");
};

// =============================================================================
// Waste Type Mapping
// =============================================================================

export const mapWasteTypeToEnum = (wasteType: string): WasteType => {
  const normalizedType = wasteType.toLowerCase().trim();

  const mapping: Record<string, WasteType> = {
    plastic: WasteType.Plastic,
    paper: WasteType.Paper,
    cardboard: WasteType.Paper,
    metal: WasteType.Metal,
    aluminum: WasteType.Metal,
    glass: WasteType.Glass,
    organic: WasteType.Organic,
    food: WasteType.Organic,
    compost: WasteType.Organic,
    ewaste: WasteType.EWaste,
    "e-waste": WasteType.EWaste,
    electronic: WasteType.EWaste,
    electronics: WasteType.EWaste,
  };

  return mapping[normalizedType] ?? WasteType.Other;
};

// =============================================================================
// On-Chain Read Operations
// =============================================================================

/**
 * Check if an event hash has already been used on-chain
 */
export const isEventUsedOnChain = async (eventHash: string): Promise<boolean> => {
  try {
    const contract = getContract(getProvider());
    return (await contract.isEventUsed(eventHash)) as boolean;
  } catch (error) {
    console.error("Failed to check event usage on-chain:", error);
    return false; // Assume not used if we can't check
  }
};

/**
 * Get user's on-chain balance
 */
export const getBalanceOnChain = async (walletAddress: string): Promise<bigint> => {
  try {
    const contract = getContract(getProvider());
    return (await contract.balanceOf(walletAddress)) as bigint;
  } catch (error) {
    console.error("Failed to get on-chain balance:", error);
    return 0n;
  }
};

/**
 * Get user's full on-chain statistics
 */
export const getUserStatsOnChain = async (walletAddress: string): Promise<UserChainStats> => {
  try {
    const contract = getContract(getProvider());
    const [balance, earned, redeemed, records] = (await contract.getUserStats(
      walletAddress
    )) as [bigint, bigint, bigint, bigint];

    return {
      balance,
      totalEarned: earned,
      totalRedeemed: redeemed,
      recordCount: records,
    };
  } catch (error) {
    console.error("Failed to get user stats on-chain:", error);
    return {
      balance: 0n,
      totalEarned: 0n,
      totalRedeemed: 0n,
      recordCount: 0n,
    };
  }
};

/**
 * Get global on-chain statistics
 */
export const getGlobalStatsOnChain = async (): Promise<GlobalChainStats> => {
  try {
    const contract = getContract(getProvider());
    const [events, minted, burned] = (await contract.getGlobalStats()) as [
      bigint,
      bigint,
      bigint
    ];

    return {
      totalEvents: events,
      totalMinted: minted,
      totalBurned: burned,
    };
  } catch (error) {
    console.error("Failed to get global stats on-chain:", error);
    return {
      totalEvents: 0n,
      totalMinted: 0n,
      totalBurned: 0n,
    };
  }
};

// =============================================================================
// On-Chain Write Operations
// =============================================================================

/**
 * Record a recycling event on-chain
 */
export const recordRecyclingOnChain = async (
  eventHash: string,
  userWallet: string,
  points: number,
  wasteType: WasteType
): Promise<RecordRecyclingResult> => {
  try {
    const signer = getServiceSigner();
    const contract = getContract(signer);

    const tx = await contract.recordRecycling(
      eventHash,
      userWallet,
      BigInt(points),
      wasteType
    );

    const receipt: TransactionReceipt = await tx.wait();

    return {
      success: true,
      txHash: receipt.hash,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to record recycling on-chain:", message);

    return {
      success: false,
      error: message,
    };
  }
};

/**
 * Batch record multiple recycling events on-chain (gas efficient)
 */
export const batchRecordRecyclingOnChain = async (
  events: Array<{
    eventHash: string;
    userWallet: string;
    points: number;
    wasteType: WasteType;
  }>
): Promise<RecordRecyclingResult> => {
  try {
    const signer = getServiceSigner();
    const contract = getContract(signer);

    const eventHashes = events.map((e) => e.eventHash);
    const users = events.map((e) => e.userWallet);
    const points = events.map((e) => BigInt(e.points));
    const wasteTypes = events.map((e) => e.wasteType);

    const tx = await contract.batchRecordRecycling(
      eventHashes,
      users,
      points,
      wasteTypes
    );

    const receipt: TransactionReceipt = await tx.wait();

    return {
      success: true,
      txHash: receipt.hash,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to batch record on-chain:", message);

    return {
      success: false,
      error: message,
    };
  }
};

/**
 * Redeem (burn) points on-chain
 */
export const redeemOnChain = async (
  userWallet: string,
  points: number,
  rewardType: string,
  redemptionId: string
): Promise<RedeemResult> => {
  try {
    const signer = getServiceSigner();
    const contract = getContract(signer);

    const tx = await contract.redeem(
      userWallet,
      BigInt(points),
      rewardType,
      redemptionId
    );

    const receipt: TransactionReceipt = await tx.wait();

    return {
      success: true,
      txHash: receipt.hash,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to redeem on-chain:", message);

    return {
      success: false,
      error: message,
    };
  }
};

/**
 * Anchor a merkle root on-chain for audit trail
 */
export const anchorMerkleRootOnChain = async (
  merkleRoot: string,
  fromTimestamp: number,
  toTimestamp: number,
  recordCount: number
): Promise<RecordRecyclingResult> => {
  try {
    const signer = getServiceSigner();
    const contract = getContract(signer);

    const tx = await contract.anchorMerkleRoot(
      merkleRoot,
      BigInt(fromTimestamp),
      BigInt(toTimestamp),
      BigInt(recordCount)
    );

    const receipt: TransactionReceipt = await tx.wait();

    return {
      success: true,
      txHash: receipt.hash,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to anchor merkle root on-chain:", message);

    return {
      success: false,
      error: message,
    };
  }
};

// =============================================================================
// Utility Functions
// =============================================================================

/**
 * Check if blockchain is properly configured and accessible
 */
export const isBlockchainConfigured = async (): Promise<boolean> => {
  try {
    // Check required config
    if (!process.env.CONTRACT_ADDRESS) {
      return false;
    }

    if (!process.env.PRIVATE_KEY && !process.env.PRIVATE_KEY) {
      return false;
    }

    // Try to fetch chain ID
    const provider = getProvider();
    const network = await provider.getNetwork();
    return network.chainId > 0n;
  } catch {
    return false;
  }
};

/**
 * Get the current chain ID
 */
export const getCurrentChainId = async (): Promise<number> => {
  try {
    const provider = getProvider();
    const network = await provider.getNetwork();
    return Number(network.chainId);
  } catch {
    return getChainId(); // Return configured chain ID as fallback
  }
};

/**
 * Get the service account address
 */
export const getServiceAccountAddress = (): string => {
  const signer = getServiceSigner();
  return signer.address;
};

/**
 * Get comprehensive blockchain health status
 */
export interface BlockchainHealthStatus {
  ok: boolean;
  chainId: number;
  latestBlock: number;
  backendWallet: string;
  contractAddress: string;
  contractReachable: boolean;
  rpcUrl: string;
  error?: string;
}

export const getBlockchainHealth = async (): Promise<BlockchainHealthStatus> => {
  const result: BlockchainHealthStatus = {
    ok: false,
    chainId: 0,
    latestBlock: 0,
    backendWallet: "",
    contractAddress: "",
    contractReachable: false,
    rpcUrl: getRpcUrl(),
  };

  try {
    // Check contract address is configured
    if (!process.env.CONTRACT_ADDRESS) {
      result.error = "CONTRACT_ADDRESS not configured";
      return result;
    }
    result.contractAddress = process.env.CONTRACT_ADDRESS;

    // Check private key is configured
    if (!process.env.PRIVATE_KEY && !process.env.PRIVATE_KEY) {
      result.error = "PRIVATE_KEY not configured";
      return result;
    }

    // Get provider and network info
    const provider = getProvider();
    const [network, blockNumber] = await Promise.all([
      provider.getNetwork(),
      provider.getBlockNumber(),
    ]);

    result.chainId = Number(network.chainId);
    result.latestBlock = blockNumber;

    // Get service account address
    result.backendWallet = getServiceAccountAddress();

    // Check contract is reachable by calling a view function
    try {
      const contract = getContract(provider);
      // Try to get global stats to verify contract is deployed and reachable
      await contract.getGlobalStats();
      result.contractReachable = true;
    } catch (contractError) {
      result.contractReachable = false;
      result.error = `Contract not reachable: ${(contractError as Error).message}`;
      return result;
    }

    result.ok = true;
    return result;
  } catch (error) {
    result.error = (error as Error).message;
    return result;
  }
};

// =============================================================================
// Legacy Compatibility (keeping old exports for backward compatibility)
// =============================================================================

/**
 * @deprecated Use recordRecyclingOnChain instead
 */
export const recordRecyclingActivityOnChain = async (
  rewardPoints: number
): Promise<string> => {
  console.warn(
    "recordRecyclingActivityOnChain is deprecated. Use recordRecyclingOnChain instead."
  );

  // This is a stub for backward compatibility
  // In practice, you'd need the full event details
  throw new Error(
    "Legacy recordRecyclingActivityOnChain requires migration to new API"
  );
};

/**
 * @deprecated Use getBalanceOnChain instead
 */
export const getTotalRewardsOnChain = async (
  walletAddress: string
): Promise<number> => {
  const balance = await getBalanceOnChain(walletAddress);
  return Number(balance);
};
