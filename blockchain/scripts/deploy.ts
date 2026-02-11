import { network } from "hardhat";

const { viem } = await network.connect();
const [deployer] = await viem.getWalletClients();

console.log("Deploying RecyclingRewardsV2 with:", deployer.account.address);

const rewards = await viem.deployContract("RecyclingRewardsV2");

console.log("RecyclingRewardsV2 deployed to:", rewards.address);
