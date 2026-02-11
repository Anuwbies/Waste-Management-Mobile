/**
 * Smoke Test — API Readiness Verification
 * ========================================
 * Tests the full flow: register → login → upload image → verify response → check history.
 *
 * Prerequisites:
 *   1. MongoDB running
 *   2. AI service running:  cd AI && python inference_service.py
 *   3. Backend running:     cd backend && npm run dev
 *
 * Run:
 *   cd backend
 *   npx ts-node src/tests/smoke_test.ts [path/to/test-image.jpg]
 *
 * If no image path given, creates a tiny synthetic JPEG for testing.
 */

import http from "http";
import https from "https";
import fs from "fs";
import path from "path";
import crypto from "crypto";

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------
const BASE_URL = process.env.BASE_URL || "http://127.0.0.1:5000";
const AI_URL = process.env.AI_SERVICE_URL || "http://127.0.0.1:8000";

const TEST_EMAIL = `smoketest_${Date.now()}@test.com`;
const TEST_PASSWORD = "SmokeTest123!";
const TEST_NAME = "Smoke Tester";

// Counters
let passed = 0;
let failed = 0;
const results: { test: string; status: "PASS" | "FAIL"; detail?: string }[] = [];

// ---------------------------------------------------------------------------
// HTTP helpers (zero deps)
// ---------------------------------------------------------------------------
function request(
  method: string,
  url: string,
  opts?: {
    headers?: Record<string, string>;
    body?: string | Buffer;
    timeout?: number;
  }
): Promise<{ status: number; body: string; headers: http.IncomingHttpHeaders }> {
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

function multipartUpload(
  url: string,
  filePath: string,
  fieldName: string,
  token?: string
): Promise<{ status: number; body: string; headers: http.IncomingHttpHeaders }> {
  return new Promise((resolve, reject) => {
    const boundary = `----SmokeTest${Date.now()}`;
    const fileName = path.basename(filePath);
    const ext = path.extname(filePath).toLowerCase();
    const mimeMap: Record<string, string> = {
      ".jpg": "image/jpeg",
      ".jpeg": "image/jpeg",
      ".png": "image/png",
    };
    const mime = mimeMap[ext] || "image/jpeg";
    const fileData = fs.readFileSync(filePath);

    const header = Buffer.from(
      `--${boundary}\r\n` +
        `Content-Disposition: form-data; name="${fieldName}"; filename="${fileName}"\r\n` +
        `Content-Type: ${mime}\r\n\r\n`
    );
    const footer = Buffer.from(`\r\n--${boundary}--\r\n`);
    const payload = Buffer.concat([header, fileData, footer]);

    const parsed = new URL(url);
    const transport = parsed.protocol === "https:" ? https : http;
    const headers: Record<string, string> = {
      "Content-Type": `multipart/form-data; boundary=${boundary}`,
      "Content-Length": payload.length.toString(),
    };
    if (token) headers["Authorization"] = `Bearer ${token}`;

    const req = transport.request(
      {
        method: "POST",
        hostname: parsed.hostname,
        port: parsed.port,
        path: parsed.pathname,
        headers,
        timeout: 30_000,
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () =>
          resolve({
            status: res.statusCode ?? 0,
            body: Buffer.concat(chunks).toString("utf-8"),
            headers: res.headers,
          })
        );
      }
    );
    req.on("timeout", () => {
      req.destroy();
      reject(new Error("timeout"));
    });
    req.on("error", reject);
    req.write(payload);
    req.end();
  });
}

// ---------------------------------------------------------------------------
// Test helpers
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

/**
 * Create a minimal valid JPEG file (2x2 red pixels) for testing
 * when no real image is provided.
 */
function createSyntheticJpeg(outPath: string): void {
  // Smallest valid JPEG: SOI + APP0 + quant table + frame + scan + EOI
  // Instead, we use a known tiny JPEG hex dump (2x2 red image).
  // This 631-byte blob is a valid JPEG.
  const RED_JPEG_HEX =
    "ffd8ffe000104a46494600010100000100010000ffdb004300080606" +
    "070605080707070909080a0c140d0c0b0b0c1912130f141d1a1f1e" +
    "1d1a1c1c20242e2720222c231c1c2837292c30313434341f27393d" +
    "38323c2e333432ffdb0043010909090c0b0c180d0d18322115213232" +
    "323232323232323232323232323232323232323232323232323232323232" +
    "3232323232323232323232323232ffc00011080002000203012200021101" +
    "031101ffc4001f000001050101010101010000000000000000010203040506" +
    "0708090a0bffc400b5100002010303020403050504040000017d01020300" +
    "041105122131410613516107227114328191a1082342b1c11552d1f0243362" +
    "7282090a161718191a25262728292a3435363738393a434445464748494a" +
    "535455565758595a636465666768696a737475767778797a838485868788898a" +
    "92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5" +
    "c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7" +
    "f8f9faffc4001f0100030101010101010101010000000000000102030405060708" +
    "090a0bffc400b51100020102040403040705040400010277000102031104052131" +
    "0612415107226171133281a1082391b1c1152433f0d1721662254334e190a2b253" +
    "43190a35173f1263646a27282927181a28292a38393a45464748494a5556575859" +
    "5a65666768696a75767778797a85868788898a94959697989a9aa3a4a5a6a7a8a9" +
    "aab4b5b6b7b8b9bac4c5c6c7c8c9cad4d5d6d7d8d9dae4e5e6e7e8e9eaf4f5f6" +
    "f7f8f9faffda000c03010002110311003f00fbfc2800a002800a002800a0ffd9";

  try {
    fs.writeFileSync(outPath, Buffer.from(RED_JPEG_HEX, "hex"));
  } catch {
    // Fallback: write an even simpler approach — PNG 1x1 pixel
    // But since we need JPEG, just create a file with JPEG magic bytes
    const minimal = Buffer.from([
      0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
    ]);
    fs.writeFileSync(outPath, minimal);
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
async function main() {
  const testImageArg = process.argv[2];
  let testImagePath: string;

  if (testImageArg && fs.existsSync(testImageArg)) {
    testImagePath = path.resolve(testImageArg);
    console.log(`Using provided test image: ${testImagePath}`);
  } else {
    // Create synthetic JPEG
    testImagePath = path.join(__dirname, "__smoke_test_image.jpg");
    createSyntheticJpeg(testImagePath);
    console.log(`Created synthetic test image: ${testImagePath}`);
  }

  console.log(`\nBackend: ${BASE_URL}`);
  console.log(`AI:      ${AI_URL}\n`);

  // ---- 1. Health checks ----
  console.log("--- Health Checks ---");

  try {
    const h = await request("GET", `${BASE_URL}/health`);
    assert("GET /health returns 200", h.status === 200);
    const hj = JSON.parse(h.body);
    assert("GET /health has status=ok", hj.status === "ok");
  } catch (e) {
    assert("GET /health reachable", false, String(e));
  }

  try {
    const ai = await request("GET", `${BASE_URL}/health/ai`);
    const aij = JSON.parse(ai.body);
    assert("GET /health/ai returns ok", aij.ok === true);
    assert("GET /health/ai has latencyMs", typeof aij.latencyMs === "number");
    assert("GET /health/ai has modelLoaded=true", aij.modelLoaded === true);
    assert(
      "GET /health/ai has modelVersion",
      typeof aij.modelVersion === "string" && aij.modelVersion.length > 0
    );
  } catch (e) {
    assert("GET /health/ai reachable", false, String(e));
  }

  // ---- 2. Register + Login ----
  console.log("\n--- Auth ---");
  let token = "";

  try {
    const reg = await jsonPost(`${BASE_URL}/auth/register`, {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      name: TEST_NAME,
    });
    assert("POST /auth/register returns 201", reg.status === 201);
  } catch (e) {
    assert("POST /auth/register reachable", false, String(e));
  }

  try {
    const login = await jsonPost(`${BASE_URL}/auth/login`, {
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
    });
    assert("POST /auth/login returns 200", login.status === 200);
    const lj = JSON.parse(login.body);
    token = lj.token || "";
    assert("POST /auth/login returns token", token.length > 10);
  } catch (e) {
    assert("POST /auth/login reachable", false, String(e));
  }

  if (!token) {
    console.log("\n⚠️  Cannot proceed without auth token. Aborting.");
    printSummary();
    return;
  }

  // ---- 3. Upload image ----
  console.log("\n--- Upload & Classify ---");
  let classificationId = "";
  let imageUrl = "";

  try {
    const up = await multipartUpload(
      `${BASE_URL}/waste/upload`,
      testImagePath,
      "image",
      token
    );

    // Accept 201 (success) or 503 (AI down but handled gracefully)
    if (up.status === 503) {
      assert(
        "POST /waste/upload returns 503 when AI down (graceful)",
        true
      );
      const uj = JSON.parse(up.body);
      assert(
        "503 body has message",
        typeof uj.message === "string" && uj.message.length > 0
      );
      console.log(
        "\n⚠️  AI service is unavailable — skipping response schema checks."
      );
      printSummary();
      return;
    }

    assert("POST /waste/upload returns 201", up.status === 201);

    const uj = JSON.parse(up.body);

    // Validate top-level fields
    assert("Response has message", typeof uj.message === "string");
    assert("Response has classification object", typeof uj.classification === "object");
    assert("Response has totalRewards (number)", typeof uj.totalRewards === "number");

    const c = uj.classification;
    classificationId = c.id || "";
    imageUrl = c.imageUrl || "";

    // Validate classification fields
    assert("classification.id exists", typeof c.id === "string" && c.id.length > 0);
    assert("classification.imageUrl exists", typeof c.imageUrl === "string" && c.imageUrl.startsWith("/uploads/"));
    assert(
      "classification.wasteType is canonical",
      ["plastic", "paper", "metal", "glass", "organic", "e-waste", "unknown"].includes(c.wasteType)
    );
    assert(
      "classification.confidence is 0..1",
      typeof c.confidence === "number" && c.confidence >= 0 && c.confidence <= 1
    );
    assert("classification.rewardPoints is number", typeof c.rewardPoints === "number");
    assert("classification.status is approved|denied", ["approved", "denied"].includes(c.status));

    // Optional but expected AI fields
    assert("classification.rawLabel exists", typeof c.rawLabel === "string");
    assert("classification.modelVersion exists", typeof c.modelVersion === "string");
    assert("classification.topK is array", Array.isArray(c.topK));

    if (Array.isArray(c.topK) && c.topK.length > 0) {
      const first = c.topK[0];
      assert("topK[0].label is string", typeof first.label === "string");
      assert("topK[0].canonicalLabel is string", typeof first.canonicalLabel === "string");
      assert("topK[0].score is number", typeof first.score === "number");
      assert(
        "topK is sorted descending",
        c.topK.length < 2 || c.topK[0].score >= c.topK[1].score
      );
    }

    // Reward logic consistency
    if (c.status === "denied") {
      assert("denied → rewardPoints == 0", c.rewardPoints === 0);
    }
    if (c.status === "approved") {
      assert("approved → rewardPoints > 0", c.rewardPoints > 0);
    }

    console.log(
      `\n  📋 Classification: ${c.wasteType} (${(c.confidence * 100).toFixed(1)}%) ` +
        `raw="${c.rawLabel}" status=${c.status} pts=${c.rewardPoints}`
    );
  } catch (e) {
    assert("POST /waste/upload succeeds", false, String(e));
  }

  // ---- 4. Image accessibility ----
  console.log("\n--- Image Access ---");
  if (imageUrl) {
    try {
      const img = await request("GET", `${BASE_URL}${imageUrl}`);
      assert("Uploaded image is accessible via /uploads/", img.status === 200);
    } catch (e) {
      assert("Uploaded image reachable", false, String(e));
    }
  }

  // ---- 5. History ----
  console.log("\n--- History ---");
  try {
    const hist = await request("GET", `${BASE_URL}/waste/history?page=1&limit=5`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    assert("GET /waste/history returns 200", hist.status === 200);
    const hj = JSON.parse(hist.body);
    assert("history has classifications array", Array.isArray(hj.classifications));
    assert("history has pagination object", typeof hj.pagination === "object");
    assert("history contains at least 1 record", hj.classifications.length >= 1);

    if (hj.classifications.length > 0) {
      const first = hj.classifications[0];
      assert("history record has _id or id", !!(first._id || first.id));
      assert("history record has wasteType", typeof first.wasteType === "string");
      assert("history record has confidence", typeof first.confidence === "number");
      assert("history record has rewardPoints", typeof first.rewardPoints === "number");
      assert("history record has rawLabel (schema fixed)", typeof first.rawLabel === "string");
      assert("history record has status (schema fixed)", typeof first.status === "string");
      assert("history record has createdAt", typeof first.createdAt === "string");
    }
  } catch (e) {
    assert("GET /waste/history succeeds", false, String(e));
  }

  // ---- 6. Error cases ----
  console.log("\n--- Error Handling ---");

  // Upload without auth
  try {
    const noauth = await multipartUpload(
      `${BASE_URL}/waste/upload`,
      testImagePath,
      "image"
    );
    assert("Upload without auth → 401", noauth.status === 401);
  } catch (e) {
    assert("Upload without auth test", false, String(e));
  }

  // Upload without file (empty body)
  try {
    const nofile = await request("POST", `${BASE_URL}/waste/upload`, {
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: "{}",
    });
    assert(
      "Upload without file → 400",
      nofile.status === 400
    );
  } catch (e) {
    assert("Upload without file test", false, String(e));
  }

  // Cleanup synthetic image
  if (!testImageArg) {
    try { fs.unlinkSync(testImagePath); } catch { /* ok */ }
  }

  printSummary();
}

function printSummary() {
  console.log("\n" + "=".repeat(60));
  console.log("SMOKE TEST SUMMARY");
  console.log("=".repeat(60));
  console.log(`  Total : ${passed + failed}`);
  console.log(`  Pass  : ${passed}`);
  console.log(`  Fail  : ${failed}`);
  console.log("=".repeat(60));

  if (failed > 0) {
    console.log("\nFailed tests:");
    for (const r of results) {
      if (r.status === "FAIL") {
        console.log(`  ❌ ${r.test}${r.detail ? ": " + r.detail : ""}`);
      }
    }
  }

  console.log(`\nResult: ${failed === 0 ? "✅ ALL PASS" : "❌ SOME FAILURES"}\n`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(2);
});
