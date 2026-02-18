/**
 * Confidence Threshold Test
 * ==========================
 * Verifies that POST /recycle correctly gates rewards on CNN confidence:
 *   - confidence < 0.80  →  denied, 0 points, no txHash
 *   - confidence >= 0.80  →  approved, positive points
 *
 * Prerequisites:
 *   1. MongoDB running
 *   2. Backend running:  cd backend && npm run dev
 *
 * Run:
 *   cd backend
 *   npx ts-node src/tests/confidence_threshold_test.ts
 */

import http from "http";
import https from "https";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const BASE_URL = process.env.BASE_URL || "http://127.0.0.1:5000";

const UNIQUE = Date.now();
const TEST_EMAIL = `conftest_${UNIQUE}@test.com`;
const TEST_PASSWORD = "ConfTest123!";
const TEST_NAME = "Confidence Tester";

let passed = 0;
let failed = 0;
const results: { test: string; status: "PASS" | "FAIL"; detail?: string }[] =
  [];

// ---------------------------------------------------------------------------
// HTTP helpers (zero deps — mirrors smoke_test.ts)
// ---------------------------------------------------------------------------
function request(
  method: string,
  url: string,
  opts?: {
    headers?: Record<string, string>;
    body?: string | Buffer;
    timeout?: number;
  }
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
        })
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

function jsonPost(
  url: string,
  data: object,
  token?: string
): Promise<{ status: number; body: string; headers: http.IncomingHttpHeaders }> {
  const payload = JSON.stringify(data);
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(payload).toString(),
  };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  return request("POST", url, { headers, body: payload });
}

// ---------------------------------------------------------------------------
// Assertion helper
// ---------------------------------------------------------------------------
function assert(
  testName: string,
  condition: boolean,
  detail?: string
): void {
  if (condition) {
    passed++;
    results.push({ test: testName, status: "PASS" });
    console.log(`  ✅ PASS: ${testName}`);
  } else {
    failed++;
    results.push({ test: testName, status: "FAIL", detail });
    console.log(`  ❌ FAIL: ${testName}${detail ? " — " + detail : ""}`);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  console.log("╔══════════════════════════════════════════════════════╗");
  console.log("║   Confidence Threshold Test                         ║");
  console.log("╚══════════════════════════════════════════════════════╝\n");

  // ── 0. Check backend health ─────────────────────────────────────────
  console.log("[0] Checking backend health...");
  try {
    await request("GET", `${BASE_URL}/health`, { timeout: 5_000 });
    console.log("  Backend is reachable.\n");
  } catch {
    console.error("  ✖ Backend not reachable at", BASE_URL);
    process.exit(1);
  }

  // ── 1. Register ─────────────────────────────────────────────────────
  console.log("[1] Registering test user...");
  const regRes = await jsonPost(`${BASE_URL}/auth/register`, {
    name: TEST_NAME,
    email: TEST_EMAIL,
    password: TEST_PASSWORD,
  });
  const regJson = JSON.parse(regRes.body);
  assert("Register returns 201", regRes.status === 201, `got ${regRes.status}`);
  const token: string = regJson.token;
  assert("Token received", !!token, "no token in response");
  console.log();

  if (!token) {
    console.error("Cannot continue without auth token.");
    process.exit(1);
  }

  // ── 2. Submit with LOW confidence (0.49) ────────────────────────────
  console.log("[2] POST /recycle  confidence=0.49 (below 0.80 threshold)...");
  const lowRes = await jsonPost(
    `${BASE_URL}/recycle`,
    {
      wasteType: "plastic",
      quantity: 1,
      metadata: {
        confidence: 0.497,
        binType: "Recycling Bin",
        source: "cnn",
        isRecyclable: true,
        idempotencyKey: `low_${UNIQUE}`,
      },
    },
    token
  );
  const lowJson = JSON.parse(lowRes.body);
  console.log("  Response status:", lowRes.status);
  console.log("  Body (summary):", JSON.stringify(lowJson, null, 2).slice(0, 500));

  assert(
    "Low confidence → HTTP 200",
    lowRes.status === 200,
    `got ${lowRes.status}`
  );
  assert(
    'Low confidence → status "denied"',
    lowJson.status === "denied",
    `got status="${lowJson.status}"`
  );
  assert(
    "Low confidence → 0 rewardPoints",
    lowJson.log?.rewardPoints === 0,
    `got rewardPoints=${lowJson.log?.rewardPoints}`
  );
  assert(
    "Low confidence → reason present",
    typeof lowJson.reason === "string" && lowJson.reason.length > 0,
    `reason="${lowJson.reason}"`
  );
  assert(
    "Low confidence → no txHash",
    !lowJson.log?.txHash,
    `txHash="${lowJson.log?.txHash}"`
  );
  assert(
    "Low confidence → confidence echoed",
    typeof lowJson.confidence === "number",
    `confidence=${lowJson.confidence}`
  );
  console.log();

  // ── 3. Submit with HIGH confidence (0.92) ───────────────────────────
  console.log("[3] POST /recycle  confidence=0.92 (above 0.80 threshold)...");
  const highRes = await jsonPost(
    `${BASE_URL}/recycle`,
    {
      wasteType: "plastic",
      quantity: 1,
      metadata: {
        confidence: 0.92,
        binType: "Recycling Bin",
        source: "cnn",
        isRecyclable: true,
        idempotencyKey: `high_${UNIQUE}`,
      },
    },
    token
  );
  const highJson = JSON.parse(highRes.body);
  console.log("  Response status:", highRes.status);
  console.log("  Body (summary):", JSON.stringify(highJson, null, 2).slice(0, 500));

  assert(
    "High confidence → HTTP 200",
    highRes.status === 200,
    `got ${highRes.status}`
  );
  assert(
    'High confidence → status NOT "denied"',
    highJson.status !== "denied",
    `got status="${highJson.status}"`
  );
  assert(
    "High confidence → positive rewardPoints",
    (highJson.log?.rewardPoints ?? 0) > 0,
    `got rewardPoints=${highJson.log?.rewardPoints}`
  );
  assert(
    "High confidence → confidence echoed",
    typeof highJson.confidence === "number",
    `confidence=${highJson.confidence}`
  );
  console.log();

  // ── 4. Submit at BOUNDARY (exactly 0.80) ────────────────────────────
  console.log("[4] POST /recycle  confidence=0.80 (boundary — should be approved)...");
  const boundaryRes = await jsonPost(
    `${BASE_URL}/recycle`,
    {
      wasteType: "metal",
      quantity: 1,
      metadata: {
        confidence: 0.80,
        binType: "Recycling Bin",
        source: "cnn",
        isRecyclable: true,
        idempotencyKey: `boundary_${UNIQUE}`,
      },
    },
    token
  );
  const boundaryJson = JSON.parse(boundaryRes.body);
  console.log("  Response status:", boundaryRes.status);

  assert(
    "Boundary (0.80) → HTTP 200",
    boundaryRes.status === 200,
    `got ${boundaryRes.status}`
  );
  assert(
    'Boundary (0.80) → NOT denied',
    boundaryJson.status !== "denied",
    `got status="${boundaryJson.status}"`
  );
  assert(
    "Boundary (0.80) → positive rewardPoints",
    (boundaryJson.log?.rewardPoints ?? 0) > 0,
    `got rewardPoints=${boundaryJson.log?.rewardPoints}`
  );
  console.log();

  // ── 5. Submit with NO confidence (missing metadata) ─────────────────
  console.log("[5] POST /recycle  no metadata.confidence (should still proceed)...");
  const noConfRes = await jsonPost(
    `${BASE_URL}/recycle`,
    {
      wasteType: "glass",
      quantity: 1,
      metadata: {
        binType: "Recycling Bin",
        source: "manual",
        idempotencyKey: `noconf_${UNIQUE}`,
      },
    },
    token
  );
  const noConfJson = JSON.parse(noConfRes.body);
  console.log("  Response status:", noConfRes.status);

  assert(
    "No confidence → HTTP 200",
    noConfRes.status === 200,
    `got ${noConfRes.status}`
  );
  assert(
    "No confidence → NOT denied (no confidence means no gating)",
    noConfJson.status !== "denied",
    `got status="${noConfJson.status}"`
  );
  console.log();

  // ── Summary ─────────────────────────────────────────────────────────
  console.log("═══════════════════════════════════════════════════════");
  console.log(`  ${passed} passed, ${failed} failed`);
  console.log("═══════════════════════════════════════════════════════");

  if (failed > 0) {
    console.log("\nFailed tests:");
    results.filter((r) => r.status === "FAIL").forEach((r) => {
      console.log(`  • ${r.test}: ${r.detail ?? ""}`);
    });
  }

  process.exit(failed > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(2);
});
