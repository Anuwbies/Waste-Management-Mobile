import { beforeEach, describe, it } from "node:test";
import { expect } from "chai";
import { network } from "hardhat";

type RecyclingRecord = {
  wasteType: bigint;
  rewardPoints: bigint;
  timestamp: bigint;
};

const toBigInt = (value: bigint | number): bigint =>
  typeof value === "bigint" ? value : BigInt(value);

const WasteType = {
  Plastic: 0,
  Paper: 1,
  Metal: 2,
  Glass: 3,
  Organic: 4,
  EWaste: 5,
} as const;

describe("RecyclingRewards", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner, userA, userB] = await viem.getWalletClients();

  let rewards: Awaited<ReturnType<typeof viem.deployContract>>;

  beforeEach(async () => {
    rewards = await viem.deployContract("RecyclingRewards");
  });

  it("User can record recycling and gets correct reward points", async () => {
    const rewardsAsUser = await viem.getContractAt(
      "RecyclingRewards",
      rewards.address,
      {
        client: { public: publicClient, wallet: userA },
      }
    );

    await rewardsAsUser.write.recordRecycling([WasteType.Plastic]);

    const totalRewards = (await publicClient.readContract({
      address: rewards.address,
      abi: rewards.abi,
      functionName: "totalRewards",
      args: [userA.account.address],
    })) as bigint;

    expect(totalRewards).to.equal(10n);
  });

  it("Stores multiple recycling actions for the same user", async () => {
    const rewardsAsUser = await viem.getContractAt(
      "RecyclingRewards",
      rewards.address,
      {
        client: { public: publicClient, wallet: userA },
      }
    );

    await rewardsAsUser.write.recordRecycling([WasteType.Glass]);
    await rewardsAsUser.write.recordRecycling([WasteType.Metal]);

    const records = (await publicClient.readContract({
      address: rewards.address,
      abi: rewards.abi,
      functionName: "getMyRecords",
      account: userA.account.address,
    })) as RecyclingRecord[];

    expect(records.length).to.equal(2);
    expect(toBigInt(records[0].wasteType)).to.equal(3n);
    expect(toBigInt(records[0].rewardPoints)).to.equal(12n);
    expect(toBigInt(records[1].wasteType)).to.equal(2n);
    expect(toBigInt(records[1].rewardPoints)).to.equal(15n);
  });

  it("Total rewards increase correctly across multiple actions", async () => {
    const rewardsAsUser = await viem.getContractAt(
      "RecyclingRewards",
      rewards.address,
      {
        client: { public: publicClient, wallet: userA },
      }
    );

    await rewardsAsUser.write.recordRecycling([WasteType.Paper]);
    await rewardsAsUser.write.recordRecycling([WasteType.EWaste]);

    const totalRewards = (await publicClient.readContract({
      address: rewards.address,
      abi: rewards.abi,
      functionName: "totalRewards",
      args: [userA.account.address],
    })) as bigint;

    expect(totalRewards).to.equal(28n);
  });

  it("getMyRecords returns the correct data per user", async () => {
    const rewardsAsUserA = await viem.getContractAt(
      "RecyclingRewards",
      rewards.address,
      {
        client: { public: publicClient, wallet: userA },
      }
    );
    const rewardsAsUserB = await viem.getContractAt(
      "RecyclingRewards",
      rewards.address,
      {
        client: { public: publicClient, wallet: userB },
      }
    );

    await rewardsAsUserA.write.recordRecycling([WasteType.Organic]);
    await rewardsAsUserB.write.recordRecycling([WasteType.Metal]);

    const recordsA = (await publicClient.readContract({
      address: rewards.address,
      abi: rewards.abi,
      functionName: "getMyRecords",
      account: userA.account.address,
    })) as RecyclingRecord[];

    const recordsB = (await publicClient.readContract({
      address: rewards.address,
      abi: rewards.abi,
      functionName: "getMyRecords",
      account: userB.account.address,
    })) as RecyclingRecord[];

    expect(recordsA.length).to.equal(1);
    expect(recordsB.length).to.equal(1);
    expect(toBigInt(recordsA[0].rewardPoints)).to.equal(5n);
    expect(toBigInt(recordsB[0].rewardPoints)).to.equal(15n);
  });
});
