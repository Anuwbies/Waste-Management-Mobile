import fs from "fs";
import path from "path";
import { Contract, JsonRpcProvider, Wallet, InterfaceAbi } from "ethers";

type ContractArtifact = {
  abi: InterfaceAbi;
};

const ganacheUrl = process.env.GANACHE_RPC_URL || "http://127.0.0.1:8545";
const contractAddress = process.env.CONTRACT_ADDRESS;
const abiPath =
  process.env.CONTRACT_ABI_PATH ||
  path.resolve(
    __dirname,
    "..",
    "..",
    "..",
    "blockchain",
    "artifacts",
    "contracts",
    "Counter.sol",
    "Counter.json"
  );

const readAbi = (): InterfaceAbi => {
  const json = fs.readFileSync(abiPath, "utf8");
  const artifact = JSON.parse(json) as ContractArtifact;
  return artifact.abi;
};

const provider = new JsonRpcProvider(ganacheUrl);
const contractAbi: InterfaceAbi = readAbi();

const getContract = (runner: JsonRpcProvider | Wallet): Contract => {
  if (!contractAddress) {
    throw new Error("CONTRACT_ADDRESS is not set");
  }

  return new Contract(contractAddress, contractAbi, runner);
};

const getSigner = (): Wallet => {
  const privateKey = process.env.GANACHE_PRIVATE_KEY;
  if (!privateKey) {
    throw new Error("GANACHE_PRIVATE_KEY is not set");
  }

  return new Wallet(privateKey, provider);
};

export const getTotalRewardsOnChain = async (
  _walletAddress: string
): Promise<number> => {
  // NOTE: The current Counter contract stores a global counter, not per user.
  // Replace this call with your real contract method (e.g., rewardsOf(address)).
  const contract = getContract(provider);
  const value = (await contract.x()) as bigint;
  return Number(value);
};

export const recordRecyclingActivityOnChain = async (
  rewardPoints: number
): Promise<string> => {
  // Sends a transaction to record the reward on-chain.
  const signer = getSigner();
  const contract = getContract(signer);
  const tx = await contract.incBy(rewardPoints);
  const receipt = await tx.wait();
  return receipt?.hash ?? tx.hash;
};
