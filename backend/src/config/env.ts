import dotenv from "dotenv";

dotenv.config();

// ---------------------------------------------------------------------------
// Validate critical env vars at startup (fail fast)
// ---------------------------------------------------------------------------
const required = ["JWT_SECRET", "MONGODB_URI"] as const;
for (const key of required) {
  if (!process.env[key]) {
    // eslint-disable-next-line no-console
    console.error(`❌  Missing required env var: ${key}`);
    process.exit(1);
  }
}

// ---------------------------------------------------------------------------
// Optional env vars used by auth features (documented here for clarity):
//
//  GOOGLE_CLIENT_ID        – Primary Google OAuth client ID
//  GOOGLE_CLIENT_IDS       – Comma-separated list of additional audience IDs
//                            (Android / iOS / web)
//
//  SMTP_HOST               – SMTP server hostname
//  SMTP_PORT               – SMTP port (465 = TLS, 587 = STARTTLS)
//  SMTP_USER               – SMTP username
//  SMTP_PASS               – SMTP password
//  SMTP_FROM               – "From" address for outgoing mail
//
// If SMTP vars are missing the email service falls back to console logging
// (dev-only), so the forgot-password flow still works during development.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// AI / Classification Config
// ---------------------------------------------------------------------------

/**
 * Minimum CNN confidence (0..1) required to approve a reward.
 * Submissions below this threshold are denied — no blockchain tx, no points.
 * Override via CNN_CONFIDENCE_THRESHOLD env var.
 */
export const CNN_CONFIDENCE_THRESHOLD: number = parseFloat(
  process.env.CNN_CONFIDENCE_THRESHOLD ?? "0.80"
);
