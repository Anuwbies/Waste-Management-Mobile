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
