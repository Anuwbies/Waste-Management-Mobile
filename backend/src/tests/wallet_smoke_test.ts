/**
 * Smoke test for HD wallet derivation.
 *
 * Run:  npx ts-node src/tests/wallet_smoke_test.ts
 *
 * Requires HD_WALLET_MNEMONIC to be set in the environment (or .env).
 */
import "../config/env"; // load dotenv
import { deriveCustodialWallet } from "../services/blockchainServiceV2";

const green = (s: string) => `\x1b[32m${s}\x1b[0m`;
const red = (s: string) => `\x1b[31m${s}\x1b[0m`;

let passed = 0;
let failed = 0;

function assert(condition: boolean, label: string) {
  if (condition) {
    console.log(green(`  ✓ ${label}`));
    passed++;
  } else {
    console.log(red(`  ✗ ${label}`));
    failed++;
  }
}

console.log("\n=== Wallet Derivation Smoke Test ===\n");

// 1. Derive indices 0, 1, 2 — should all succeed and differ
const w0 = deriveCustodialWallet(0);
const w1 = deriveCustodialWallet(1);
const w2 = deriveCustodialWallet(2);

assert(!!w0.address && w0.address.startsWith("0x"), "index 0 returns valid address");
assert(!!w1.address && w1.address.startsWith("0x"), "index 1 returns valid address");
assert(!!w2.address && w2.address.startsWith("0x"), "index 2 returns valid address");

assert(w0.address !== w1.address, "index 0 ≠ index 1");
assert(w1.address !== w2.address, "index 1 ≠ index 2");
assert(w0.address !== w2.address, "index 0 ≠ index 2");

// 2. Same index produces same address (deterministic)
const w0b = deriveCustodialWallet(0);
assert(w0.address === w0b.address, "index 0 is deterministic (same address)");
assert(w0.privateKey === w0b.privateKey, "index 0 is deterministic (same key)");

// 3. Private keys look correct (hex, 66 chars with 0x)
assert(w0.privateKey.startsWith("0x") && w0.privateKey.length === 66, "privateKey format OK");

// 4. Negative index should throw
let threwForNegative = false;
try {
  deriveCustodialWallet(-1);
} catch {
  threwForNegative = true;
}
assert(threwForNegative, "negative index throws error");

// 5. Non-integer index should throw
let threwForFloat = false;
try {
  deriveCustodialWallet(1.5);
} catch {
  threwForFloat = true;
}
assert(threwForFloat, "float index throws error");

// Summary
console.log(`\n${green(`${passed} passed`)}, ${failed > 0 ? red(`${failed} failed`) : "0 failed"}\n`);

if (failed > 0) process.exit(1);
