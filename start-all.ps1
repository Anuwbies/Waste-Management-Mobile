$ErrorActionPreference = "Continue"

$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "          RecyClean  -  Full Stack Launcher                 " -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""

function Log($label, $msg, $color) {
    Write-Host "  [$label] " -ForegroundColor $color -NoNewline
    Write-Host $msg
}

# ===========================================================================
# 1. Install dependencies (parallel)
# ===========================================================================
Log "SETUP" "Installing npm dependencies ..." "Yellow"

$installJobs = @()

if (-not (Test-Path "$ROOT\blockchain\node_modules")) {
    $installJobs += Start-Job -ScriptBlock {
        Set-Location "$using:ROOT\blockchain"
        npm install --silent 2>&1 | Out-Null
    }
    Log "SETUP" "  blockchain -> npm install" "DarkGray"
} else {
    Log "SETUP" "  blockchain -> node_modules exists, skipping" "DarkGray"
}

if (-not (Test-Path "$ROOT\backend\node_modules")) {
    $installJobs += Start-Job -ScriptBlock {
        Set-Location "$using:ROOT\backend"
        npm install --silent 2>&1 | Out-Null
    }
    Log "SETUP" "  backend    -> npm install" "DarkGray"
} else {
    Log "SETUP" "  backend    -> node_modules exists, skipping" "DarkGray"
}

if (-not (Test-Path "$ROOT\web\node_modules")) {
    $installJobs += Start-Job -ScriptBlock {
        Set-Location "$using:ROOT\web"
        npm install --silent 2>&1 | Out-Null
    }
    Log "SETUP" "  web        -> npm install" "DarkGray"
} else {
    Log "SETUP" "  web        -> node_modules exists, skipping" "DarkGray"
}

if ($installJobs.Count -gt 0) {
    Log "SETUP" "Waiting for npm installs to finish ..." "Yellow"
    $installJobs | Wait-Job | Out-Null
    $installJobs | Remove-Job -Force | Out-Null
}
Log "SETUP" "Dependencies ready" "Green"

# -- AI venv + pip --
$VENV_PYTHON = "$ROOT\AI\venv\Scripts\python.exe"
if (-not (Test-Path $VENV_PYTHON)) {
    Log "AI" "Creating Python venv ..." "Yellow"
    python -m venv "$ROOT\AI\venv"
}
Log "AI" "Checking pip dependencies ..." "DarkGray"
& $VENV_PYTHON -m pip install -q -r "$ROOT\AI\requirements.txt" 2>&1 | Out-Null
Log "AI" "Python venv ready" "Green"

Write-Host ""

# ===========================================================================
# 2. Start services
# ===========================================================================

$processes = @()

# -- 2a. AI Inference Service (port 8000) --
Log "AI" "Starting inference service on :8000 ..." "Magenta"
$aiProc = Start-Process -FilePath $VENV_PYTHON `
    -ArgumentList "inference_service.py" `
    -WorkingDirectory "$ROOT\AI" `
    -PassThru -NoNewWindow
$processes += $aiProc
Start-Sleep -Seconds 1

# -- 2b. Hardhat Node (port 8545) --
Log "CHAIN" "Starting Hardhat node on :8545 ..." "Blue"
$hardhatProc = Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "npx hardhat node" `
    -WorkingDirectory "$ROOT\blockchain" `
    -PassThru -NoNewWindow
$processes += $hardhatProc

Log "CHAIN" "Waiting for Hardhat node ..." "DarkGray"
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try {
        $body = '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:8545" `
            -Method Post -ContentType "application/json" `
            -Body $body -ErrorAction Stop -TimeoutSec 2
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {
        # not ready yet
    }
}

if ($ready) {
    Log "CHAIN" "Hardhat node ready" "Green"
} else {
    Log "CHAIN" "WARNING: Hardhat node did not respond after 60s - continuing anyway" "Yellow"
}

# -- 2c. Deploy smart contract --
Log "CHAIN" "Deploying RecyclingRewardsV2 ..." "Blue"
Push-Location "$ROOT\blockchain"
$deployOutput = cmd.exe /c "npx hardhat run scripts/deployV2.ts --network localhost 2>&1"
Pop-Location

$contractAddr = ""
if ($deployOutput) {
    foreach ($line in $deployOutput) {
        $lineStr = $line.ToString()
        if ($lineStr -match "Contract address:\s*(0x[0-9a-fA-F]+)") {
            $contractAddr = $Matches[1]
        }
        if ($lineStr -match "CONTRACT_ADDRESS=(0x[0-9a-fA-F]+)") {
            $contractAddr = $Matches[1]
        }
    }
}

if ($contractAddr) {
    Log "CHAIN" "Contract deployed at: $contractAddr" "Green"
    $env:CONTRACT_ADDRESS = $contractAddr
} else {
    Log "CHAIN" "WARNING: Could not parse contract address from deploy output" "Yellow"
    if ($deployOutput) {
        foreach ($line in $deployOutput) {
            Write-Host "       $line" -ForegroundColor DarkGray
        }
    }
}

# -- 2d. Backend (port 5000) --
Log "API" "Starting backend on :5000 ..." "Cyan"

if (-not $env:MONGODB_URI)       { $env:MONGODB_URI = "mongodb://127.0.0.1:27017/recycling_rewards" }
if (-not $env:JWT_SECRET)        { $env:JWT_SECRET  = "dev-secret-key-that-is-32-chars!!" }
if (-not $env:RPC_URL)           { $env:RPC_URL     = "http://127.0.0.1:8545" }
if (-not $env:CHAIN_ID)          { $env:CHAIN_ID    = "31337" }
if (-not $env:PRIVATE_KEY)       { $env:PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" }
if (-not $env:AI_SERVICE_URL)    { $env:AI_SERVICE_URL = "http://127.0.0.1:8000" }
if (-not $env:CONTRACT_ABI_PATH) { $env:CONTRACT_ABI_PATH = "../blockchain/artifacts/contracts/RecyclingRewardsV2.sol/RecyclingRewardsV2.json" }
if (-not $env:PORT)              { $env:PORT = "5000" }

$backendProc = Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "npm run dev" `
    -WorkingDirectory "$ROOT\backend" `
    -PassThru -NoNewWindow
$processes += $backendProc
Start-Sleep -Seconds 2

# -- 2e. Web Admin Panel (port 5173) --
Log "WEB" "Starting admin panel on :5173 ..." "Green"
$webProc = Start-Process -FilePath "cmd.exe" `
    -ArgumentList "/c", "npm run dev" `
    -WorkingDirectory "$ROOT\web" `
    -PassThru -NoNewWindow
$processes += $webProc

Start-Sleep -Seconds 2

# ===========================================================================
# 3. Summary
# ===========================================================================
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Green
Write-Host "              All services are running!                     " -ForegroundColor Green
Write-Host "-----------------------------------------------------------" -ForegroundColor Green
Write-Host "  AI Inference   ->  http://localhost:8000                  " -ForegroundColor Green
Write-Host "  Hardhat Node   ->  http://localhost:8545                  " -ForegroundColor Green
Write-Host "  Backend API    ->  http://localhost:5000                  " -ForegroundColor Green
Write-Host "  Web Admin      ->  http://localhost:5173                  " -ForegroundColor Green
Write-Host "-----------------------------------------------------------" -ForegroundColor Green
if ($contractAddr) {
    Write-Host "  Contract       ->  $contractAddr" -ForegroundColor Green
}
Write-Host "" -ForegroundColor Green
Write-Host "  Press Ctrl+C to stop all services                        " -ForegroundColor Yellow
Write-Host "===========================================================" -ForegroundColor Green
Write-Host ""

# ===========================================================================
# 4. Wait + graceful shutdown on Ctrl+C
# ===========================================================================
try {
    while ($true) {
        Start-Sleep -Seconds 3

        foreach ($proc in $processes) {
            if ($proc.HasExited) {
                $name = switch ($proc.Id) {
                    $aiProc.Id      { "AI Inference" }
                    $hardhatProc.Id { "Hardhat Node" }
                    $backendProc.Id { "Backend" }
                    $webProc.Id     { "Web Admin" }
                    default         { "Unknown" }
                }
                Log "WARN" "$name (PID $($proc.Id)) exited with code $($proc.ExitCode)" "Yellow"
            }
        }

        $allExited = ($processes | Where-Object { -not $_.HasExited }).Count -eq 0
        if ($allExited) {
            Log "STOP" "All services have stopped." "Red"
            break
        }
    }
}
finally {
    Write-Host ""
    Log "STOP" "Shutting down all services ..." "Red"

    foreach ($proc in $processes) {
        if (-not $proc.HasExited) {
            try {
                # Kill the cmd.exe and its children (node, npx, etc.)
                $procId = $proc.Id
                # Use taskkill /T to kill the entire process tree
                cmd.exe /c "taskkill /PID $procId /T /F >nul 2>&1"
            } catch {
                # ignore cleanup errors
            }
        }
    }

    Log "STOP" "All services stopped. Goodbye!" "Green"
}
