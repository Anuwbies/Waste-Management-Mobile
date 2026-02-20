/**
 * Chain-Authority Test
 * ====================
 * Verifies that blockchain is the source of truth for reward balances:
 *
 *   1. GET /rewards/balance returns the on-chain balance (source: "chain").
 *   2. Manually tampering MongoDB user.totalRewards does NOT change the
 *      balance returned by /rewards/balance.
 *   3. An integrity-drift warning is included when Mongo ≠ chain.
 *
 * Prerequisites:
 *   1. MongoDB running
 *   2. Local Hardhat node running:   cd blockchain && npx hardhat node
 *   3. Contract deployed:            cd blockchain && npx hardhat run scripts/deployV2.ts --network localhost
 *   4. Backend running with CONTRACT_ADDRESS & RPC_URL set:
 *        cd backend && npm run dev
 *
 * Run:
 *   cd backend
 *   npx ts-node src/tests/chain_authority_test.ts
 */

import http from "http";
import https from "https";
import crypto from "crypto";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const BASE_URL = process.env.BASE_URL || "http://127.0.0.1:5000";
const MONGO_URI =
  process.env.MONGO_URI || "mongodb://127.0.0.1:27017/waste-recycling";

const TEST_EMAIL = `chaintest_${Date.now()}@test.com`;
const TEST_PASSWORD = "ChainTest123!";
const TEST_NAME = "Chain Tester";

let passed = 0;
let failed = 0;
const results: { test: string; status: "PASS" | "FAIL"; detail?: string }[] =
  [];

// ---------------------------------------------------------------------------
// HTTP helpers (zero deps — mirrors smoke_test pattern)
// ---------------------------------------------------------------------------
function request(
  method: string,
  url: string,
  opts?: {
    headers?: Record<string, string>;
    body?: string | Buffer;
    timeout?: number;
  },
): Promise<{
  status: number;
  body: string;
  headers: http.IncomingHttpHeaders;
}> {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const transport = parsed.protocol === "https:" ? https : http;
    const reqOpts: http.RequestOptions = {
      method,
      hostname: parsed.hostname,
      port: parsed.port,
      path: parsed.pathname + parsed.search,
      headers: opts?.headers ?? {},
      timeout: opts?.timeout ?? 15_000,
    };
    const req = transport.request(reqOpts, (res) => {
      const chunks: Buffer[] = [];
      res.on("data", (c) => chunks.push(c));
      res.on("end", () =>
        resolve({
          status: res.statusCode ?? 0,
          body: Buffer.concat(chunks).toString("utf-8"),
          headers: res.headers,
        }),
      );
    });
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("timeout"));
    });
    req.on("error", reject);
    if (opts?.body) req.write(opts.body);
    req.end();
  });
}

function jsonPost(url: string, data: object, token?: string) {
  const payload = JSON.stringify(data);
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload).toString(),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return request("POST", url, { headers, body: payload });
}

function jsonGet(url: string, token: string) {
  return request("GET", url, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------
function assert(
  test: string,
  condition: boolean,
  detail?: string,
): asserts condition {
  if (condition) {
    passed++;
    results.push({ test, status: "PASS" });
    console.log(`  ✅ ${test}`);
  } else {
    failed++;
    results.push({ test, status: "FAIL", detail });
    console.log(`  ❌ ${test}${detail ? ` — ${detail}` : ""}`);
  }
}

// ---------------------------------------------------------------------------
// MongoDB direct manipulation (uses native driver via dynamic import)
// ---------------------------------------------------------------------------
async function tamperMongoBalance(
  userId: string,
  newBalance: number,
): Promise<void> {
  // Dynamic import so the test still compiles even without mongodb driver
  const { MongoClient } = await import("mongodb");
  const client = new MongoClient(MONGO_URI);
  try {
    await client.connect();
    const db = client.db();
    const result = await db.collection("users").updateOne(
      { _id: userId as any },
      { $set: { totalRewards: newBalance } },
    );
    if (result.matchedCount === 0) {
      // Try with ObjectId
      const { ObjectId } = await import("mongodb");
      await db.collection("users").updateOne(
        { _id: new ObjectId(userId) as any },
        { $set: { totalRewards: newBalance } },
      );
    }
    console.log(
      `  [mongo] Tampered user.totalRewards → ${newBalance} for userId=${userId}`,
    );
  } finally {
    await client.close();
  }
}

// ---------------------------------------------------------------------------
// Main test
// ---------------------------------------------------------------------------
async function main() {
  console.log("\n╔══════════════════════════════════════════════════╗");
  console.log("║   Chain-Authority Test — Blockchain = Truth      ║");
  console.log("╚══════════════════════════════════════════════════╝\n");

  // ── Step 1: Register a test user ──────────────────────────────────────
  console.log("▸ Step 1: Register test user");
  const regRes = await jsonPost(`${BASE_URL}/auth/register`, {
    name: TEST_NAME,
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
  });
  assert(
    "Register returns 201",
    regRes.status === 201,
    `got ${regRes.status}: ${regRes.body.slice(0, 200)}`,
  );
  const regBody = JSON.parse(regRes.body);
  const token: string = regBody.token;
  const userId: string = regBody.user?.id || regBody.user?._id;
  assert("Token received", !!token);
  assert("User ID received", !!userId);
  console.log(`  userId = ${userId}`);

  // ── Step 2: Fetch initial balance ─────────────────────────────────────
  console.log("\n▸ Step 2: Fetch initial balance from /rewards/balance");
  const bal1Res = await jsonGet(`${BASE_URL}/rewards/balance`, token);
  assert(
    "/rewards/balance returns 200",
    bal1Res.status === 200,
    `got ${bal1Res.status}`,
  );
  const bal1 = JSON.parse(bal1Res.body);
  console.log(`  balance=${bal1.balance}  source=${bal1.source}`);
  assert(
    "Initial balance is 0",
    bal1.balance === 0,
    `got ${bal1.balance}`,
  );
  assert(
    "Source is chain or cache",
    bal1.source === "chain" || bal1.source === "cache",
    `got ${bal1.source}`,
  );

  // ── Step 3: Tamper MongoDB — set totalRewards to 99999 ───────────────
  console.log("\n▸ Step 3: Tamper MongoDB user.totalRewards → 99999");
  await tamperMongoBalance(userId, 99999);

  // ── Step 4: Fetch balance again — should STILL be 0 (from chain) ─────
  console.log("\n▸ Step 4: Fetch balance again — must ignore Mongo tamper");
  const bal2Res = await jsonGet(`${BASE_URL}/rewards/balance`, token);
  assert(
    "/rewards/balance still returns 200",
    bal2Res.status === 200,
    `got ${bal2Res.status}`,
  );
  const bal2 = JSON.parse(bal2Res.body);
  console.log(
    `  balance=${bal2.balance}  source=${bal2.source}  integrityWarning=${bal2.integrityWarning ?? "none"}`,
  );

  if (bal2.source === "chain") {
    // Blockchain is configured — the main assertion:
    assert(
      "Balance is STILL 0 (chain ignores Mongo tamper)",
      bal2.balance === 0,
      `got ${bal2.balance} — chain was supposed to be authoritative!`,
    );
    assert(
      "Integrity drift warning present",
      !!bal2.integrityWarning,
      "Expected integrityWarning because Mongo=99999 ≠ chain=0",
    );
    console.log(`  ✔ Chain authority confirmed: Mongo says 99999, API returns 0`);
  } else {
    // Blockchain not running — test degrades gracefully
    console.log(
      "  ⚠ Blockchain not configured — source is 'cache', skipping chain assertions.",
    );
    console.log(
      "    To test fully, run: cd blockchain && npx hardhat node  (in another terminal)",
    );
    assert(
      "Fallback: balance matches Mongo cache when chain unavailable",
      bal2.balance === 99999,
      `got ${bal2.balance}`,
    );
  }

  // ── Step 5: Check /rewards/stats ─────────────────────────────────────
  console.log("\n▸ Step 5: Verify /rewards/stats also uses chain");
  const statsRes = await jsonGet(`${BASE_URL}/rewards/stats`, token);
  assert(
    "/rewards/stats returns 200",
    statsRes.status === 200,
    `got ${statsRes.status}`,
  );
  const stats = JSON.parse(statsRes.body);
  console.log(`  totalEarned=${stats.totalEarned}  source=${stats.source ?? "n/a"}`);
  if (stats.source === "chain") {
    assert(
      "Stats totalEarned is from chain (0), not Mongo (99999)",
      stats.totalEarned === 0,
      `got ${stats.totalEarned}`,
    );
  }

  // ── Step 6: Restore Mongo balance ────────────────────────────────────
  console.log("\n▸ Step 6: Restore MongoDB balance → 0 (cleanup)");
  await tamperMongoBalance(userId, 0);

  // ── Summary ──────────────────────────────────────────────────────────
  console.log("\n╔══════════════════════════════════════════════════╗");
  console.log(
    `║   Results: ${passed} passed, ${failed} failed` +
      " ".repeat(Math.max(0, 36 - `${passed}`.length - `${failed}`.length)) +
      "║",
  );
  console.log("╚══════════════════════════════════════════════════╝\n");

  if (failed > 0) {
    console.log("Failed tests:");
    results
      .filter((r) => r.status === "FAIL")
      .forEach((r) => console.log(`  ✗ ${r.test}: ${r.detail ?? ""}`));
  }

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
