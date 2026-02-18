/**
 * Email Service
 *
 * Sends transactional emails (e.g. password-reset OTP) via SMTP.
 *
 * Required env vars (optional in dev – falls back to console logging):
 *   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM
 */

import nodemailer, { Transporter } from "nodemailer";

// ---------------------------------------------------------------------------
// Singleton transporter (lazy-created)
// ---------------------------------------------------------------------------

let transporter: Transporter | null = null;

const getTransporter = (): Transporter | null => {
  if (transporter) return transporter;

  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;

  if (!SMTP_HOST || !SMTP_PORT || !SMTP_USER || !SMTP_PASS) {
    // SMTP not configured – let caller know so it can fall back
    return null;
  }

  transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT),
    secure: Number(SMTP_PORT) === 465,
    auth: {
      user: SMTP_USER,
      pass: SMTP_PASS,
    },
  });

  return transporter;
};

// ---------------------------------------------------------------------------
// Public helpers
// ---------------------------------------------------------------------------

const fromAddress = (): string =>
  process.env.SMTP_FROM ?? "noreply@recycleapp.local";

/**
 * Send a password-reset OTP email.
 *
 * In dev mode (no SMTP configured), the OTP is logged to the console so the
 * flow can be tested without an email provider.
 */
export const sendPasswordResetOtp = async (
  email: string,
  otp: string,
): Promise<void> => {
  const transport = getTransporter();

  const subject = "Your Password Reset Code";
  const text = [
    `Hello,`,
    ``,
    `Your password reset code is: ${otp}`,
    ``,
    `This code expires in 10 minutes. If you did not request a password reset, please ignore this email.`,
    ``,
    `— Recycle Rewards Team`,
  ].join("\n");

  const html = `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: auto;">
      <h2 style="color: #2e7d32;">Password Reset Code</h2>
      <p>Hello,</p>
      <p>Your password reset code is:</p>
      <p style="font-size: 32px; letter-spacing: 6px; font-weight: bold; text-align: center; color: #1b5e20;">
        ${otp}
      </p>
      <p>This code expires in <strong>10 minutes</strong>.</p>
      <p style="color: #888; font-size: 12px;">If you did not request this, you can safely ignore this email.</p>
    </div>
  `;

  if (!transport) {
    // DEV fallback – log to console
    // eslint-disable-next-line no-console
    console.log(
      `\n📧 [DEV] Password-reset OTP for ${email}: ${otp}\n` +
        `   (SMTP not configured – email not actually sent)\n`,
    );
    return;
  }

  await transport.sendMail({
    from: fromAddress(),
    to: email,
    subject,
    text,
    html,
  });
};
