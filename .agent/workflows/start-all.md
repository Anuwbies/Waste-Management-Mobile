---
description: Start all project services with a single command
---

# Start All Services

Run this from the project root directory to start everything at once:

```powershell
.\start-all.ps1
```

Or double-click `start-all.bat` from File Explorer.

## What it does (in order):
1. Installs npm dependencies for blockchain, backend, and web (in parallel, skips if node_modules exists)
2. Creates Python venv and installs pip packages for the AI service (skips if already done)
3. Starts the **AI Inference Service** on port 8000 (Python FastAPI)
4. Starts **Hardhat Node** on port 8545 (local blockchain)
5. Waits for Hardhat to be ready, then **deploys the smart contract**
6. Sets backend environment variables and starts the **Backend API** on port 5000
7. Starts the **Web Admin Panel** on port 5173 (Vite dev server)

## Stopping
Press `Ctrl+C` in the terminal — it will gracefully shut down all services.

## Ports
| Service         | Port  |
|-----------------|-------|
| AI Inference    | 8000  |
| Hardhat Node    | 8545  |
| Backend API     | 5000  |
| Web Admin       | 5173  |
