import { beforeEach, describe, it } from "node:test";
import { expect } from "chai";
import { network } from "hardhat";
import { keccak256, encodePacked, Address, Hash } from "viem";

const WasteType = {
  Plastic: 0,
  Paper: 1,
  Metal: 2,
  Glass: 3,
  Organic: 4,
  EWaste: 5,
  Other: 6,
} as const;

// Helper to generate unique event hashes
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

describe("RecyclingRewardsV2", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [admin, minter, userA, userB, unauthorized] =
    await viem.getWalletClients();

  let rewards: Awaited<ReturnType<typeof viem.deployContract>>;
  const MINTER_ROLE = keccak256(encodePacked(["string"], ["MINTER_ROLE"]));

  beforeEach(async () => {
    rewards = await viem.deployContract("RecyclingRewardsV2", [
      admin.account.address,
    ]);

    // Grant minter role to the minter account
    const rewardsAsAdmin = await viem.getContractAt(
      "RecyclingRewardsV2",
      rewards.address,
      { client: { public: publicClient, wallet: admin } }
    );
    await rewardsAsAdmin.write.grantRole([MINTER_ROLE, minter.account.address]);
  });

  describe("Deployment", () => {
    it("Should set admin as DEFAULT_ADMIN_ROLE", async () => {
      const DEFAULT_ADMIN_ROLE =
        "0x0000000000000000000000000000000000000000000000000000000000000000" as Hash;
      const hasRole = await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "hasRole",
        args: [DEFAULT_ADMIN_ROLE, admin.account.address],
      });
      expect(hasRole).to.equal(true);
    });

    it("Should set admin as MINTER_ROLE", async () => {
      const hasRole = await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "hasRole",
        args: [MINTER_ROLE, admin.account.address],
      });
      expect(hasRole).to.equal(true);
    });
  });

  describe("recordRecycling", () => {
    it("Should record recycling and credit points to user", async () => {
      const eventHash = generateEventHash("user123", WasteType.Plastic, 1000);
      const points = 10n;

      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      await rewardsAsMinter.write.recordRecycling([
        eventHash,
        userA.account.address,
        points,
        WasteType.Plastic,
      ]);

      const balance = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "balanceOf",
        args: [userA.account.address],
      })) as bigint;

      expect(balance).to.equal(points);
    });

    it("Should emit RecyclingRecorded event", async () => {
      const eventHash = generateEventHash("user456", WasteType.Metal, 2000);
      const points = 15n;

      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const txHash = await rewardsAsMinter.write.recordRecycling([
        eventHash,
        userA.account.address,
        points,
        WasteType.Metal,
      ]);

      const receipt = await publicClient.waitForTransactionReceipt({
        hash: txHash,
      });
      expect(receipt.logs.length).to.be.greaterThan(0);
    });

    it("Should reject duplicate event hashes", async () => {
      const eventHash = generateEventHash("user789", WasteType.Paper, 3000);
      const points = 8n;

      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      // First call should succeed
      await rewardsAsMinter.write.recordRecycling([
        eventHash,
        userA.account.address,
        points,
        WasteType.Paper,
      ]);

      // Second call with same eventHash should fail
      try {
        await rewardsAsMinter.write.recordRecycling([
          eventHash,
          userB.account.address,
          points,
          WasteType.Paper,
        ]);
        expect.fail("Should have thrown");
      } catch (error: unknown) {
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        expect(errorMessage).to.include("Event already rewarded");
      }
    });

    it("Should reject calls from unauthorized accounts", async () => {
      const eventHash = generateEventHash("userABC", WasteType.Glass, 4000);

      const rewardsAsUnauthorized = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: unauthorized } }
      );

      try {
        await rewardsAsUnauthorized.write.recordRecycling([
          eventHash,
          userA.account.address,
          12n,
          WasteType.Glass,
        ]);
        expect.fail("Should have thrown");
      } catch (error: unknown) {
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        expect(errorMessage).to.include("AccessControl");
      }
    });

    it("Should update total statistics", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const eventHash1 = generateEventHash("stats1", WasteType.Plastic, 5000);
      const eventHash2 = generateEventHash("stats2", WasteType.Metal, 5001);

      await rewardsAsMinter.write.recordRecycling([
        eventHash1,
        userA.account.address,
        10n,
        WasteType.Plastic,
      ]);
      await rewardsAsMinter.write.recordRecycling([
        eventHash2,
        userA.account.address,
        15n,
        WasteType.Metal,
      ]);

      const stats = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "getGlobalStats",
      })) as [bigint, bigint, bigint];

      expect(stats[0]).to.equal(2n); // totalRecyclingEvents
      expect(stats[1]).to.equal(25n); // totalPointsMinted
      expect(stats[2]).to.equal(0n); // totalPointsBurned
    });
  });

  describe("redeem", () => {
    it("Should deduct points from user balance", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      // First give user some points
      const eventHash = generateEventHash("redeem1", WasteType.EWaste, 6000);
      await rewardsAsMinter.write.recordRecycling([
        eventHash,
        userA.account.address,
        100n,
        WasteType.EWaste,
      ]);

      // Redeem some points
      const redemptionId = keccak256(
        encodePacked(["string"], ["redemption-001"])
      );
      await rewardsAsMinter.write.redeem([
        userA.account.address,
        30n,
        "coffee_voucher",
        redemptionId,
      ]);

      const balance = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "balanceOf",
        args: [userA.account.address],
      })) as bigint;

      expect(balance).to.equal(70n);
    });

    it("Should reject redemption with insufficient balance", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const redemptionId = keccak256(
        encodePacked(["string"], ["redemption-002"])
      );

      try {
        await rewardsAsMinter.write.redeem([
          userA.account.address,
          1000n,
          "expensive_item",
          redemptionId,
        ]);
        expect.fail("Should have thrown");
      } catch (error: unknown) {
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        expect(errorMessage).to.include("Insufficient balance");
      }
    });

    it("Should track total redeemed correctly", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const eventHash = generateEventHash("redeem2", WasteType.Organic, 7000);
      await rewardsAsMinter.write.recordRecycling([
        eventHash,
        userA.account.address,
        50n,
        WasteType.Organic,
      ]);

      const redemptionId = keccak256(
        encodePacked(["string"], ["redemption-003"])
      );
      await rewardsAsMinter.write.redeem([
        userA.account.address,
        20n,
        "snack",
        redemptionId,
      ]);

      const stats = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "getUserStats",
        args: [userA.account.address],
      })) as [bigint, bigint, bigint, bigint];

      expect(stats[0]).to.equal(30n); // balance
      expect(stats[1]).to.equal(50n); // earned
      expect(stats[2]).to.equal(20n); // redeemed
      expect(stats[3]).to.equal(1n); // records
    });
  });

  describe("batchRecordRecycling", () => {
    it("Should record multiple events in one transaction", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const eventHashes = [
        generateEventHash("batch1", WasteType.Plastic, 8001),
        generateEventHash("batch2", WasteType.Paper, 8002),
        generateEventHash("batch3", WasteType.Metal, 8003),
      ];
      const users = [
        userA.account.address,
        userA.account.address,
        userB.account.address,
      ];
      const points = [10n, 8n, 15n];
      const wasteTypes = [WasteType.Plastic, WasteType.Paper, WasteType.Metal];

      await rewardsAsMinter.write.batchRecordRecycling([
        eventHashes,
        users,
        points,
        wasteTypes,
      ]);

      const balanceA = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "balanceOf",
        args: [userA.account.address],
      })) as bigint;

      const balanceB = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "balanceOf",
        args: [userB.account.address],
      })) as bigint;

      expect(balanceA).to.equal(18n); // 10 + 8
      expect(balanceB).to.equal(15n);
    });

    it("Should skip duplicate event hashes in batch", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const duplicateHash = generateEventHash(
        "duplicate",
        WasteType.Glass,
        9000
      );

      // First, record one event
      await rewardsAsMinter.write.recordRecycling([
        duplicateHash,
        userA.account.address,
        12n,
        WasteType.Glass,
      ]);

      // Now try batch with the duplicate
      const eventHashes = [
        duplicateHash, // Already used - should be skipped
        generateEventHash("newBatch", WasteType.Other, 9001),
      ];

      await rewardsAsMinter.write.batchRecordRecycling([
        eventHashes,
        [userB.account.address, userB.account.address],
        [10n, 5n],
        [WasteType.Glass, WasteType.Other],
      ]);

      const balanceB = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "balanceOf",
        args: [userB.account.address],
      })) as bigint;

      // Only 5 points from the non-duplicate
      expect(balanceB).to.equal(5n);
    });
  });

  describe("isEventUsed", () => {
    it("Should return false for unused event hash", async () => {
      const eventHash = generateEventHash("unused", WasteType.Plastic, 10000);

      const isUsed = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "isEventUsed",
        args: [eventHash],
      })) as boolean;

      expect(isUsed).to.equal(false);
    });

    it("Should return true for used event hash", async () => {
      const eventHash = generateEventHash("used", WasteType.Paper, 10001);

      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      await rewardsAsMinter.write.recordRecycling([
        eventHash,
        userA.account.address,
        8n,
        WasteType.Paper,
      ]);

      const isUsed = (await publicClient.readContract({
        address: rewards.address,
        abi: rewards.abi,
        functionName: "isEventUsed",
        args: [eventHash],
      })) as boolean;

      expect(isUsed).to.equal(true);
    });
  });

  describe("anchorMerkleRoot", () => {
    it("Should emit MerkleRootAnchored event", async () => {
      const rewardsAsMinter = await viem.getContractAt(
        "RecyclingRewardsV2",
        rewards.address,
        { client: { public: publicClient, wallet: minter } }
      );

      const merkleRoot = keccak256(
        encodePacked(["string"], ["test-merkle-root"])
      );

      const txHash = await rewardsAsMinter.write.anchorMerkleRoot([
        merkleRoot,
        1000n,
        2000n,
        50n,
      ]);

      const receipt = await publicClient.waitForTransactionReceipt({
        hash: txHash,
      });
      expect(receipt.status).to.equal("success");
      expect(receipt.logs.length).to.be.greaterThan(0);
    });
  });
});
