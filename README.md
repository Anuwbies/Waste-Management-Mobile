AI-Powered Waste Classification & Blockchain Reward System

RecyClean is a full-stack decentralized reward system that encourages proper waste segregation by combining:

📱 Flutter Mobile App

🧠 AI Image Classification (TFLite / Python Inference Service)

🖥 Node.js + Express Backend

🔗 Ethereum Smart Contracts (Hardhat)

Users scan waste, AI classifies it, backend validates confidence, and blockchain records rewards.

🏗 System Architecture
Flutter App
    ↓
Backend API (Node/Express)
    ↓
AI Inference Service (Python FastAPI)
    ↓
Blockchain (Hardhat / Ethereum)
📦 Tech Stack
Mobile

Flutter

google_sign_in

HTTP API integration

Backend

Node.js

Express

TypeScript

MongoDB (Mongoose)

Ethers.js v6

AI

Python

TensorFlow Lite

FastAPI

Pillow / NumPy

Blockchain

Hardhat

Solidity

Ethereum (local dev chainId 31337)

⚙️ Environment Setup
1️⃣ Blockchain (Hardhat)
Install dependencies
cd blockchain
npm install
npx hardhat compile
npx hardhat node
npx hardhat run scripts/deployV2.ts --network localhost

2️⃣ Backend (Node + Express)
Install dependencies
cd backend
npm install

PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/recycling_rewards
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
CONTRACT_ADDRESS=0x5fbdb2315678afecb367f032d93f642f64180aa3
CONTRACT_ABI_PATH=../blockchain/artifacts/contracts/RecyclingRewardsV2.sol/RecyclingRewardsV2.json

RPC_URL=http://127.0.0.1:8545
CHAIN_ID=31337

JWT_SECRET=dev-secret-key
GOOGLE_CLIENT_ID=127507564653-ev16rej74t096hhhlhpb240a0k1f90j7.apps.googleusercontent.com

AI_SERVICE_URL=http://127.0.0.1:8000

SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=anal.pawig.up@phinmaed.com
SMTP_PASS=lbyt enqf hmsj ltwa
SMTP_FROM=RecyClean <noreply@recyclean.com>

HD_WALLET_MNEMONIC=health issue alter retreat horn glory shoe garment spider height human amount
HD_WALLET_ENCRYPTION_KEY=670b8b454ff9e91572bb200a46549676c6d027d6ab3601960796ddca7d42ee7a

npm run dev

3️⃣ AI Inference Service
Install dependencies
cd AI
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate (Windows)
pip install -r requirements.txt

uvicorn inference_service:app --host 0.0.0.0 --port 8000 or python inference_service.py


4️⃣ Mobile App (Flutter)
Install packages
cd mobile
flutter pub get

Configure API base URL

Edit:

lib/config/api_config.dart
static const String baseUrl = "http://<YOUR_LOCAL_IP>:5000";
For Android emulator:

http://10.0.2.2:5000

Google OAuth Setup

Using google_sign_in + backend verification.

In Google Cloud Console:

Create OAuth consent screen

Create:

Android OAuth Client

Web OAuth Client

Android:

Add SHA-1 fingerprint

Ensure package name matches

In Flutter:

GoogleSignIn(
  serverClientId: "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
);

GoogleSignIn(
  serverClientId: "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com",
);