import { describe, it } from "node:test";
import { network } from "hardhat";
import { keccak256, encodePacked, Hash } from "viem";

const WasteType = {
  Plastic: 0,
  Paper: 1,
  Metal: 2,
  Glass: 3,
  Organic: 4,
  EWaste: 5,
  Other: 6,
} as const;

const generateEventHash = (
  userId: string,
  wasteType: number,
  timestamp: number
): Hash => {
  return keccak256(
    encodePacked(
      ["string", "uint8", "uint256"],
      [userId, wasteType, BigInt(timestamp)]
    )
  );
};

describe("Gas Cost Monitoring", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [admin, minter, userA, userB] = await viem.getWalletClients();

  it("Measure gas costs for critical functions", async () => {
    // Deploy with admin
    const rewards = await viem.deployContract("RecyclingRewardsV2", [
      admin.account.address,
    ]);

    // Set minter
    await rewards.write.setMinter([minter.account.address], { account: admin.account });

    const rewardsAsMinter = await viem.getContractAt(
      "RecyclingRewardsV2",
      rewards.address,
      { client: { public: publicClient, wallet: minter } }
    );

    console.log("\n" + "=".repeat(85));
    console.log("Contract function".padEnd(40) + " | " + "Result (gas)".padEnd(15) + " | " + "Identified Bottleneck");
    console.log("-".repeat(85));

    // 1. recordRecycling (New User)
    let eventHash = generateEventHash("user123", WasteType.Plastic, 1000);
    let txHash = await rewardsAsMinter.write.recordRecycling([
      eventHash,
      userA.account.address,
      10n,
      WasteType.Plastic,
    ]);
    let receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log("recordRecycling (New User)".padEnd(40) + " | " + receipt.gasUsed.toString().padEnd(15) + " | Base + SSET");

    // 1.1 recordRecycling (Existing User)
    eventHash = generateEventHash("user123-2", WasteType.Paper, 1001);
    txHash = await rewardsAsMinter.write.recordRecycling([
      eventHash,
      userA.account.address,
      5n,
      WasteType.Paper,
    ]);
    receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log("recordRecycling (Existing User)".padEnd(40) + " | " + receipt.gasUsed.toString().padEnd(15) + " | Base + SSTORE");

    // 2. redeem
    const redemptionId = keccak256(encodePacked(["string"], ["redemption-001"]));
    txHash = await rewardsAsMinter.write.redeem([
      userA.account.address,
      5n,
      "coffee_voucher",
      redemptionId,
    ]);
    receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log("redeem".padEnd(40) + " | " + receipt.gasUsed.toString().padEnd(15) + " | Storage update");

    // 3. batchRecordRecycling (3 events)
    const eventHashes = [
      generateEventHash("batch1", WasteType.Plastic, 8001),
      generateEventHash("batch2", WasteType.Paper, 8002),
      generateEventHash("batch3", WasteType.Metal, 8003),
    ];
    txHash = await rewardsAsMinter.write.batchRecordRecycling([
      eventHashes,
      [userA.account.address, userA.account.address, userB.account.address],
      [10n, 8n, 15n],
      [WasteType.Plastic, WasteType.Paper, WasteType.Metal],
    ]);
    receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });
    console.log("batchRecordRecycling (3)".padEnd(40) + " | " + receipt.gasUsed.toString().padEnd(15) + " | Multi-slot update");
    console.log("=".repeat(85) + "\n");
  });
});
