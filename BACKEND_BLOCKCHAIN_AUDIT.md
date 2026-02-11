# Backend + Blockchain Audit Report

**Date:** January 2025  
**Status:** ✅ READY FOR FRONTEND CONSUMPTION

---

## Executive Summary

The backend and blockchain components have been audited and are **ready for frontend integration**. Two missing endpoints were identified and implemented during this audit:

1. `POST /waste/suggestion` - Disposal suggestions endpoint
2. `GET /health/blockchain` - Blockchain connectivity health check

---

## A. API Readiness Audit

### Complete API Coverage Table

| Endpoint | Method | Auth | Status | Notes |
|----------|--------|------|--------|-------|
| `/health` | GET | Public | ✅ Ready | Basic health check |
| `/health/blockchain` | GET | Public | ✅ Ready | **NEW** - Chain connectivity status |
| `/auth/register` | POST | Public | ✅ Ready | Returns JWT token |
| `/auth/login` | POST | Public | ✅ Ready | Returns JWT token |
| `/auth/google` | POST | Public | ✅ Ready | OAuth flow |
| `/auth/me` | GET | Protected | ✅ Ready | Current user profile |
| `/auth/me` | PUT | Protected | ✅ Ready | Update profile |
| `/waste/upload` | POST | Protected | ✅ Ready | Multipart upload, 10MB limit |
| `/waste/classify` | POST | Protected | ✅ Ready | Preview mode (no storage) |
| `/waste/suggestion` | POST | Protected | ✅ Ready | **NEW** - Disposal suggestions |
| `/waste/history` | GET | Protected | ✅ Ready | Paginated |
| `/waste/:id` | GET | Protected | ✅ Ready | Single classification |
| `/recycle` | POST | Protected | ✅ Ready | Records with blockchain |
| `/recycle/logs` | GET | Protected | ✅ Ready | Paginated history |
| `/rewards/balance` | GET | Protected | ✅ Ready | Includes chainStats |
| `/rewards/history` | GET | Protected | ✅ Ready | Filterable by type |
| `/rewards/stats` | GET | Protected | ✅ Ready | User reward statistics |
| `/rewards/options` | GET | Protected | ✅ Ready | Available redemptions |
| `/rewards/redeem` | POST | Protected | ✅ Ready | On-chain redemption |

### Request/Response Schemas

#### POST /waste/suggestion
```json
// Request
{
  "wasteType": "plastic",      // Required
  "confidence": 0.95,          // Optional
  "context": "bottle cap"      // Optional
}

// Response 200
{
  "binType": "Blue Recycling Bin",
  "steps": ["Remove any food residue", "..."],
  "warnings": ["No plastic bags in recycling bin", "..."],
  "tips": ["Check the recycling symbol", "..."],
  "localRules": null,
  "isRecyclable": true,
  "impactMessage": "Recycling one plastic bottle..."
}
```

#### GET /health/blockchain
```json
// Response 200 (healthy)
{
  "ok": true,
  "chainId": 31337,
  "latestBlock": 12345,
  "backendWallet": "0x...",
  "contractAddress": "0x...",
  "contractReachable": true,
  "rpcUrl": "http://127.0.0.1:8545"
}

// Response 503 (unhealthy)
{
  "ok": false,
  "chainId": 0,
  "latestBlock": 0,
  "backendWallet": "",
  "contractAddress": "0x...",
  "contractReachable": false,
  "rpcUrl": "http://127.0.0.1:8545",
  "error": "Contract not reachable: ..."
}
```

#### POST /recycle
```json
// Request
{
  "wasteType": "plastic",
  "imageUrl": "/uploads/waste-123.jpg",
  "confidence": 0.92,
  "points": 5,
  "binType": "Blue Recycling Bin",
  "imageHash": "abc123..."  // Optional, for duplicate detection
}

// Response 201
{
  "message": "Recycling event recorded successfully",
  "event": {
    "id": "...",
    "eventHash": "0x...",
    "status": "confirmed",
    "txHash": "0x..."
  },
  "newBalance": 150,
  "chainConfirmed": true
}
```

#### POST /rewards/redeem
```json
// Request
{
  "rewardId": "eco_voucher_10",
  "points": 100
}

// Response 200
{
  "message": "Reward redeemed successfully",
  "transaction": {
    "id": "...",
    "type": "redemption",
    "points": -100,
    "status": "confirmed",
    "txHash": "0x..."
  },
  "newBalance": 50
}
```

---

## B. Blockchain Integration Audit

### ✅ Hardhat Configuration
- **Solidity Version:** 0.8.20
- **Networks Configured:**
  - `hardhat` (default, chainId: 31337)
  - `hardhatMainnet` (mainnet fork)
  - `hardhatOp` (Optimism fork)
  - `ganache` (local, chainId: 1337)
  - `sepolia` (testnet)

### ✅ ethers.js v6 Migration Complete
- Uses `JsonRpcProvider` (not legacy `providers.JsonRpcProvider`)
- Uses `Wallet` class correctly
- BigInt handling for token amounts
- Contract instantiation with runner pattern

### ✅ Private Key Management
- Supports `PRIVATE_KEY` or `GANACHE_PRIVATE_KEY` env vars
- HD Wallet support via `HD_WALLET_MNEMONIC` for custodial wallets
- Deterministic address generation fallback

### ✅ Contract ABI Loading
- Default path: `blockchain/artifacts/contracts/RecyclingRewardsV2.sol/RecyclingRewardsV2.json`
- Configurable via `CONTRACT_ABI_PATH` env var
- Error handling for missing ABI file

---

## C. RecyclingRewardsV2.sol Contract Audit

### Contract Functions

| Function | Type | Access | Description |
|----------|------|--------|-------------|
| `recordRecycling(bytes32, address, uint256, WasteType)` | Write | MINTER_ROLE | Record recycling event |
| `batchRecordRecycling(bytes32[], address[], uint256[], WasteType[])` | Write | MINTER_ROLE | Batch record events |
| `redeem(address, uint256, RewardType, bytes32)` | Write | MINTER_ROLE | Redeem rewards |
| `balanceOf(address)` | View | Public | Get user balance |
| `isEventUsed(bytes32)` | View | Public | Check if eventHash is used |
| `getUserStats(address)` | View | Public | Get user statistics |
| `getGlobalStats()` | View | Public | Get global statistics |
| `anchorMerkleRoot(bytes32)` | Write | MINTER_ROLE | Anchor merkle root |

### ✅ Idempotency Rules
1. **eventHash uniqueness:** Contract maintains `_usedEvents` mapping
2. **Backend deduplication:** Checks DB + on-chain before recording
3. **Image hash tracking:** Prevents same image submission twice

### ✅ WasteType Enum Mapping
```typescript
// Backend (blockchainServiceV2.ts)
export enum WasteType {
  Plastic = 0,
  Paper = 1,
  Metal = 2,
  Glass = 3,
  Organic = 4,
  EWaste = 5,  // ✅ Supported
  Other = 6,
}
```

### ✅ Access Control
- Uses OpenZeppelin `AccessControl`
- `MINTER_ROLE` required for state-changing operations
- Admin can grant/revoke roles

---

## D. Reward Issuance Correctness

### Point Calculation (rewardService.ts)
```typescript
const rewardMap: Record<string, number> = {
  plastic: 5,
  metal: 8,
  glass: 6,
  paper: 4,
  organic: 3,
  "e-waste": 15,  // ✅ Added during audit
  ewaste: 15,     // Alternative spelling
};
// Default: 2 points for unknown types
```

### Idempotency Implementation (recycleController.ts)
1. Generate `eventHash` from: timestamp + userId + wasteType + points + imageHash
2. Check if eventHash exists in MongoDB (RecyclingEvent collection)
3. Check if eventHash is used on-chain via `isEventUsed()`
4. If duplicate, return existing event (no double-mint)
5. Record on-chain with `recordRecyclingOnChain()`
6. Update event status: `pending` → `confirmed` or `failed`

### Transaction Flow
```
User Request → Generate eventHash → Check DB → Check Chain
                                        ↓
                              [If duplicate: return existing]
                                        ↓
                              Record on Chain (txHash)
                                        ↓
                              Update DB status → Response
```

---

## E. Missing Items Implemented

### 1. POST /waste/suggestion ✅
- **Location:** `backend/src/controllers/wasteController.ts`
- **Route:** `backend/src/routes/wasteRoutes.ts`
- **Features:**
  - Deterministic suggestions for: plastic, paper, metal, glass, organic, e-waste
  - Confidence-based warnings
  - Generic fallback for unknown types

### 2. GET /health/blockchain ✅
- **Location:** `backend/src/index.ts`
- **Service:** `backend/src/services/blockchainServiceV2.ts` (`getBlockchainHealth()`)
- **Returns:**
  - `ok`: Boolean health status
  - `chainId`: Network chain ID
  - `latestBlock`: Current block number
  - `backendWallet`: Service account address
  - `contractAddress`: Deployed contract address
  - `contractReachable`: Contract call success
  - `rpcUrl`: RPC endpoint URL

### 3. E-Waste Support ✅
- Added to `rewardService.ts` point map
- Already existed in blockchain `WasteType` enum
- Added disposal suggestions in wasteController

---

## F. Readiness Checklist

| Item | Status |
|------|--------|
| All endpoints documented | ✅ |
| JWT authentication working | ✅ |
| Blockchain service V2 with ethers.js v6 | ✅ |
| Contract ABI auto-loading | ✅ |
| Event idempotency (DB + chain) | ✅ |
| E-waste waste type supported | ✅ |
| Health check endpoints | ✅ |
| Error handling middleware | ✅ |
| Pagination support | ✅ |
| File upload (multer) | ✅ |

---

## G. Smoke Test Plan (curl)

### Prerequisites
```bash
# Start Hardhat node
cd blockchain && npx hardhat node

# Deploy contract
npx hardhat run scripts/deploy.ts --network localhost

# Set environment variables
export CONTRACT_ADDRESS="0x..."
export PRIVATE_KEY="0xac0974..."
export MONGODB_URI="mongodb://localhost:27017/waste-recycling"
export JWT_SECRET="your-secret"

# Start backend
cd backend && npm run dev
```

### Test Commands

```bash
# 1. Health Check
curl http://localhost:5000/health

# 2. Blockchain Health
curl http://localhost:5000/health/blockchain

# 3. Register User
curl -X POST http://localhost:5000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!","name":"Test User"}'

# 4. Login
TOKEN=$(curl -s -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"Test123!"}' | jq -r '.token')

# 5. Get Profile
curl http://localhost:5000/auth/me \
  -H "Authorization: Bearer $TOKEN"

# 6. Get Disposal Suggestion
curl -X POST http://localhost:5000/waste/suggestion \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"wasteType":"plastic","confidence":0.95}'

# 7. Check Rewards Balance
curl http://localhost:5000/rewards/balance \
  -H "Authorization: Bearer $TOKEN"

# 8. Record Recycling Event
curl -X POST http://localhost:5000/recycle \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"wasteType":"plastic","imageUrl":"/uploads/test.jpg","confidence":0.92,"points":5,"binType":"Blue Bin"}'

# 9. Get Recycling Logs
curl http://localhost:5000/recycle/logs \
  -H "Authorization: Bearer $TOKEN"

# 10. Get Reward Options
curl http://localhost:5000/rewards/options \
  -H "Authorization: Bearer $TOKEN"
```

---

## H. Known Issues / Recommendations

### Medium Priority
1. **Point value discrepancy:** Frontend `api_config.dart` shows different values than backend `rewardService.ts`. Consider syncing or fetching from backend.

2. **Simulated classification:** `wasteController.ts` uses random classification. Will need integration with actual TFLite model or cloud ML service for production.

### Low Priority
1. **Rate limiting:** No rate limiting on endpoints. Consider adding `express-rate-limit`.

2. **Request validation:** Basic validation exists but could use `zod` or `joi` for comprehensive schema validation.

3. **Logging:** Consider structured logging with `winston` or `pino`.

---

## Conclusion

**The backend and blockchain are READY for frontend consumption.**

All critical endpoints are implemented and functional:
- ✅ Authentication (register, login, profile)
- ✅ Waste classification (upload, classify, history)
- ✅ Disposal suggestions (NEW)
- ✅ Recycling events (record, logs, on-chain)
- ✅ Rewards (balance, history, stats, options, redeem)
- ✅ Health checks (basic + blockchain)

The blockchain integration is properly configured with:
- ✅ ethers.js v6 compatibility
- ✅ Proper signer/provider setup
- ✅ Event idempotency (duplicate prevention)
- ✅ On-chain recording and redemption

---

*Generated by Backend + Blockchain Audit*

cd AI
pip install -r requirements.txt
python inference_service.py

# Runs on http://127.0.0.1:8000
cd backend
# Ensure .env has: AI_SERVICE_URL=http://127.0.0.1:8000
npm run dev
# Runs on http://localhost:5000

# 1) Login to get token
# 2) Upload image
curl -X POST http://localhost:5000/waste/upload -H "Authorization: Bearer $TOKEN" -F "image=@photo.jpg"