import { network } from "hardhat";

const { viem } = await network.connect();
const [deployer] = await viem.getWalletClients();

console.log("=".repeat(60));
console.log("Deploying RecyclingRewardsV2");
console.log("=".repeat(60));
console.log("Deployer address:", deployer.account.address);
console.log("Network:", network.toString());

const rewards = await viem.deployContract("RecyclingRewardsV2", [
  deployer.account.address,
]);

console.log("");
console.log("✅ RecyclingRewardsV2 deployed successfully!");
console.log("Contract address:", rewards.address);
console.log("");
console.log("Add this to your backend .env file:");
console.log(`CONTRACT_ADDRESS=${rewards.address}`);
console.log(
  'CONTRACT_ABI_PATH=../blockchain/artifacts/contracts/RecyclingRewardsV2.sol/RecyclingRewardsV2.json'
);
console.log("");
console.log("=".repeat(60));
