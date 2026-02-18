import { network } from "hardhat";

const { viem } = await network.connect();
const [deployer] = await viem.getWalletClients();

console.log("Deploying RecyclingRewards with:", deployer.account.address);

const rewards = await viem.deployContract("RecyclingRewards");

console.log("RecyclingRewards deployed to:", rewards.address);
