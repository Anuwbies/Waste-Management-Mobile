import { network } from "hardhat";
import { parseEther, toHex } from "viem";

async function main() {
  const { viem } = await network.connect();
  const [deployer, user1] = await viem.getWalletClients();
  const publicClient = await viem.getPublicClient();

  console.log("--------------------------------------------------");
  console.log("      Performance Testing Lab: Blockchain Track   ");
  console.log("--------------------------------------------------\n");

  const contract = await viem.deployContract("RecyclingRewardsV2", [deployer.account.address]);
  console.log("Contract deployed at:", contract.address, "\n");

  // Helper to generate a bytes32 hash (mocking eventHash)
  const getHash = (str: string) => {
    let hex = toHex(str);
    let padded = hex.padEnd(66, '0');
    return padded as `0x${string}`;
  };

  // Case 1: Small Input (e.g., single word/value, new user)
  console.log("Case 1: Small input / Normal input (New user record)");
  const hash1 = getHash("event1");
  const tx1Hash = await contract.write.recordRecycling([
    hash1,
    user1.account.address,
    10n,
    0 // Plastic
  ], { account: deployer.account });
  const receipt1 = await publicClient.waitForTransactionReceipt({ hash: tx1Hash });
  console.log(`Result: Success`);
  console.log(`Gas Used: ${receipt1.gasUsed.toString()}\n`);

  // Case 2: Larger Input (e.g. batch record of 50 items)
  console.log("Case 2: Larger input / Long input (Batch record 50 items)");
  const eventHashes: `0x${string}`[] = [];
  const users: `0x${string}`[] = [];
  const points: bigint[] = [];
  const wasteTypes: number[] = [];
  for (let i = 0; i < 50; i++) {
    eventHashes.push(getHash(`batch_event_${i}`));
    users.push(user1.account.address);
    points.push(5n);
    wasteTypes.push(1); // Paper
  }
  const tx2Hash = await contract.write.batchRecordRecycling([
    eventHashes,
    users,
    points,
    wasteTypes
  ], { account: deployer.account });
  const receipt2 = await publicClient.waitForTransactionReceipt({ hash: tx2Hash });
  console.log(`Result: Success`);
  console.log(`Gas Used: ${receipt2.gasUsed.toString()}\n`);

  // Case 3: Repeated call (same state update - updating existing user)
  console.log("Case 3: Repeated call (same state update)");
  const hash2 = getHash("event2");
  const tx3Hash = await contract.write.recordRecycling([
    hash2,
    user1.account.address,
    20n,
    2 // Metal
  ], { account: deployer.account });
  const receipt3 = await publicClient.waitForTransactionReceipt({ hash: tx3Hash });
  console.log(`Result: Success`);
  console.log(`Gas Used: ${receipt3.gasUsed.toString()}\n`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
