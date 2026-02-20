/**
 * Security Smoke Tests
 * =====================
 * Validates that the security hardening measures are correctly
 * wired and functioning.  Run with: npx ts-node src/tests/security_test.ts
 *
 * These are structural / unit checks — they do NOT require a running server.
 */

import { deepStripDollarKeys, stripHtml } from "../middleware/security";
import {
  registerSchema,
  loginSchema,
  recycleSchema,
  redeemSchema,
  disposalSuggestionSchema,
  updateUserSchema,
  verifyOtpSchema,
} from "../validators/schemas";

let passed = 0;
let failed = 0;

function assert(condition: boolean, label: string): void {
  if (condition) {
    passed++;
    console.log(`  ✅  ${label}`);
  } else {
    failed++;
    console.error(`  ❌  ${label}`);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. NoSQL injection — deepStripDollarKeys
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── NoSQL Injection Guard ──────────────────────────────────");

const malicious = { email: { $ne: "" }, password: { $gt: "" } };
const cleaned = deepStripDollarKeys(malicious) as Record<string, unknown>;
assert(
  JSON.stringify(cleaned) === JSON.stringify({ email: {}, password: {} }),
  "Strips $ne and $gt operators from top-level fields",
);

const nested = { data: { inner: { $regex: ".*" }, safe: "ok" } };
const cleanedNested = deepStripDollarKeys(nested) as Record<string, unknown>;
assert(
  JSON.stringify(cleanedNested) === JSON.stringify({ data: { inner: {}, safe: "ok" } }),
  "Strips $regex from deeply nested objects",
);

assert(
  deepStripDollarKeys(null) === null,
  "Null input returns null",
);

assert(
  JSON.stringify(deepStripDollarKeys([{ $in: [1] }, "ok"])) ===
    JSON.stringify([{}, "ok"]),
  "Handles arrays with operator keys",
);

// ═══════════════════════════════════════════════════════════════════════════════
// 2. XSS — stripHtml
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── XSS / HTML Strip ──────────────────────────────────────");

assert(
  stripHtml("<script>alert('xss')</script>hello") === "alert('xss')hello",
  "Strips script tags",
);

assert(
  stripHtml('<img onerror="hack()" src="x">') === "",
  "Strips img tag with event handler",
);

assert(
  stripHtml("Clean text with no HTML") === "Clean text with no HTML",
  "Leaves clean text unchanged",
);

// ═══════════════════════════════════════════════════════════════════════════════
// 3. Zod Validation — mass assignment prevention
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── Zod Validation (mass assignment) ─────────────────────");

const registerResult = registerSchema.safeParse({
  email: "test@example.com",
  password: "StrongPass1!",
  name: "Test User",
  isAdmin: true, // should be stripped
  role: "superadmin", // should be stripped
});
assert(registerResult.success === true, "Register: valid payload passes");
if (registerResult.success) {
  const data = registerResult.data as Record<string, unknown>;
  assert(!("isAdmin" in data), "Register: strips unknown 'isAdmin' field");
  assert(!("role" in data), "Register: strips unknown 'role' field");
}

const loginFail = loginSchema.safeParse({ email: "notanemail", password: "" });
assert(loginFail.success === false, "Login: rejects invalid email + empty password");

// ═══════════════════════════════════════════════════════════════════════════════
// 4. Zod Validation — type enforcement
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── Zod Validation (type enforcement) ────────────────────");

const recycleBad = recycleSchema.safeParse({ wasteType: "nuclear" });
assert(recycleBad.success === false, "Recycle: rejects invalid wasteType 'nuclear'");

const recycleGood = recycleSchema.safeParse({ wasteType: "plastic", quantity: 5 });
assert(recycleGood.success === true, "Recycle: accepts valid plastic + quantity");

const redeemBad = redeemSchema.safeParse({ rewardType: "", customPoints: -1 });
assert(redeemBad.success === false, "Redeem: rejects empty rewardType + negative points");

const redeemGood = redeemSchema.safeParse({ rewardType: "gift-card", customPoints: 100 });
assert(redeemGood.success === true, "Redeem: accepts valid redemption");

// ═══════════════════════════════════════════════════════════════════════════════
// 5. Zod Validation — HTML stripping in string fields
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── Zod Validation (XSS in fields) ───────────────────────");

const registerXss = registerSchema.safeParse({
  email: "test@example.com",
  password: "SecurePass1!",
  name: '<script>alert("xss")</script>Bob',
});
assert(registerXss.success === true, "Register: XSS name parses (tags stripped)");
if (registerXss.success) {
  assert(
    !registerXss.data.name.includes("<script>"),
    "Register: name has script tag stripped",
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6. Zod Validation — OTP format
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── Zod Validation (OTP format) ──────────────────────────");

const otpGood = verifyOtpSchema.safeParse({ email: "a@b.com", otp: "123456" });
assert(otpGood.success === true, "OTP: accepts valid 6-digit code");

const otpBad = verifyOtpSchema.safeParse({ email: "a@b.com", otp: "12345a" });
assert(otpBad.success === false, "OTP: rejects non-numeric code");

const otpShort = verifyOtpSchema.safeParse({ email: "a@b.com", otp: "12345" });
assert(otpShort.success === false, "OTP: rejects 5-digit code");

// ═══════════════════════════════════════════════════════════════════════════════
// 7. Zod Validation — update user (photoUrl)
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── Zod Validation (updateUser) ──────────────────────────");

const updateGood = updateUserSchema.safeParse({
  name: "New Name",
  photoUrl: "https://example.com/photo.jpg",
});
assert(updateGood.success === true, "UpdateUser: valid payload accepted");

const updateBadUrl = updateUserSchema.safeParse({
  photoUrl: "not-a-url",
});
assert(updateBadUrl.success === false, "UpdateUser: rejects invalid URL");

// ═══════════════════════════════════════════════════════════════════════════════
// 8. Disposal suggestion schema
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n── Zod Validation (disposalSuggestion) ──────────────────");

const suggBad = disposalSuggestionSchema.safeParse({});
assert(suggBad.success === false, "DisposalSuggestion: rejects empty body");

const suggGood = disposalSuggestionSchema.safeParse({
  wasteType: "plastic",
  confidence: 0.85,
});
assert(suggGood.success === true, "DisposalSuggestion: accepts valid payload");

// ═══════════════════════════════════════════════════════════════════════════════
// Summary
// ═══════════════════════════════════════════════════════════════════════════════
console.log("\n══════════════════════════════════════════════════════════");
console.log(`  Total:  ${passed + failed}`);
console.log(`  Passed: ${passed}`);
console.log(`  Failed: ${failed}`);
console.log("══════════════════════════════════════════════════════════\n");

if (failed > 0) {
  process.exit(1);
}
