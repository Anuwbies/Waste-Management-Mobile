# Blockchain + Backend Hardhat Test Guide

Date: 2026-02-10

This guide shows how to run Hardhat locally and connect the backend to the deployed contract for end-to-end testing.

---

## 1) Prerequisites

- Node.js and npm installed
- MongoDB running locally
- Two terminals: one for Hardhat, one for backend

---

## 2) Start Hardhat Node

From the repository root:

```powershell
cd blockchain
npx hardhat node
```

Keep this terminal running.

---

## 3) Deploy the Contract

Open a new terminal from the repo root:

```powershell
cd blockchain
npx hardhat run scripts/deployV2.ts --network localhost
```

Copy the deployed contract address from the output. You will use it as `CONTRACT_ADDRESS`.

Note:
- Use `deployV2.ts` because the backend expects `RecyclingRewardsV2` functions like `getGlobalStats()`.

---

## 4) Configure Backend Environment

Create or update backend environment variables (example uses PowerShell). Run from repo root:

```powershell
$env:MONGODB_URI = "mongodb://localhost:27017/waste-recycling"
$env:JWT_SECRET = "dev-secret"
$env:RPC_URL = "http://127.0.0.1:8545"
$env:CHAIN_ID = "31337"
$env:CONTRACT_ADDRESS = "<paste_contract_address>"
$env:PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
```

Notes:
- The private key above is Hardhat Account #0 (use for local testing only).
- If you are using a different account, replace `PRIVATE_KEY` accordingly.

---

## 5) Start the Backend

From the repo root:

```powershell
cd backend
npm install
npm run dev
```

---

## 6) Verify Blockchain Health

Run this from any terminal:

```powershell
curl http://localhost:5000/health/blockchain
```

Expected response (example):

```json
{
  "ok": true,
  "chainId": 31337,
  "latestBlock": 5,
  "backendWallet": "0x...",
  "contractAddress": "0x...",
  "contractReachable": true,
  "rpcUrl": "http://127.0.0.1:8545"
}
```

---

## 7) Run a Full Reward Flow

### 7.1 Register a user

```powershell
curl -X POST http://localhost:5000/auth/register `
  -H "Content-Type: application/json" `
  -d '{"email":"test@example.com","password":"Test123!","name":"Test User"}'
```

### 7.2 Login and store token

```powershell
$token = (curl -s -X POST http://localhost:5000/auth/login `
  -H "Content-Type: application/json" `
  -d '{"email":"test@example.com","password":"Test123!"}' | ConvertFrom-Json).token
```

### 7.3 Record a recycling event on-chain

```powershell
curl -X POST http://localhost:5000/recycle `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -d '{"wasteType":"plastic","imageUrl":"/uploads/test.jpg","confidence":0.92,"points":5,"binType":"Blue Bin"}'
```

### 7.4 Check rewards balance

```powershell
curl http://localhost:5000/rewards/balance `
  -H "Authorization: Bearer $token"
```

### 7.5 Redeem points (on-chain)

```powershell
curl -X POST http://localhost:5000/rewards/redeem `
  -H "Authorization: Bearer $token" `
  -H "Content-Type: application/json" `
  -d '{"rewardId":"eco_voucher_10","points":5}'
```

---

## 8) Common Errors and Fixes

- "CONTRACT_ADDRESS not configured"
  - Set `CONTRACT_ADDRESS` to the deployed address.

- "Contract not reachable"
  - Hardhat node may not be running, wrong RPC URL, or V1 contract deployed by mistake.
  - Redeploy with `scripts/deployV2.ts` and update `CONTRACT_ADDRESS`.

- "PRIVATE_KEY not configured"
  - Set `PRIVATE_KEY` using a Hardhat account.

- "ABI file not found"
  - Ensure contracts were compiled and artifacts exist.

---

## 9) Optional: Reset Local Chain

If you want a fresh chain state:

1. Stop the Hardhat node (Ctrl+C).
2. Restart `npx hardhat node`.
3. Redeploy the contract.
4. Update `CONTRACT_ADDRESS`.

---

## Done

You now have a local end-to-end blockchain + backend test setup running with Hardhat.
