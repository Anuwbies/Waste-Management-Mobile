/**
 * Password Policy Validator
 *
 * Enforces strong password requirements on register and reset-password flows.
 * Reusable across controllers.
 */

// ---------------------------------------------------------------------------
// Common / weak password denylist (subset – extend as needed)
// ---------------------------------------------------------------------------
const COMMON_PASSWORDS: ReadonlySet<string> = new Set([
  "password",
  "password1",
  "password123",
  "123456789012",
  "qwerty123456",
  "letmein1234",
  "welcome12345",
  "admin1234567",
  "iloveyou1234",
  "sunshine1234",
  "princess1234",
  "football1234",
  "charlie12345",
  "access123456",
  "master123456",
  "dragon123456",
  "monkey123456",
  "shadow123456",
  "passw0rd1234",
  "trustno1",
  "abc123456789",
  "changeme1234",
  "welcome1",
  "1234567890ab",
  "qwertyuiopas",
  "letmein12345",
  "p@ssw0rd1234",
  "p@ssword1234",
]);

// ---------------------------------------------------------------------------
// Policy constants
// ---------------------------------------------------------------------------
const MIN_LENGTH = 12;

// ---------------------------------------------------------------------------
// Validation result
// ---------------------------------------------------------------------------
export interface PasswordPolicyResult {
  valid: boolean;
  errors: string[];
}

// ---------------------------------------------------------------------------
// Validator
// ---------------------------------------------------------------------------

/**
 * Validate a password against the strong-password policy.
 *
 * @param password  – candidate password (plaintext)
 * @param email     – user email, used to reject passwords containing the
 *                    username portion of the address
 */
export const validatePasswordPolicy = (
  password: string,
  email?: string,
): PasswordPolicyResult => {
  const errors: string[] = [];

  // 1. Length
  if (!password || password.length < MIN_LENGTH) {
    errors.push(`Password must be at least ${MIN_LENGTH} characters long`);
  }

  // 2. Character-class checks
  if (!/[A-Z]/.test(password)) {
    errors.push("Password must contain at least one uppercase letter");
  }
  if (!/[a-z]/.test(password)) {
    errors.push("Password must contain at least one lowercase letter");
  }
  if (!/[0-9]/.test(password)) {
    errors.push("Password must contain at least one number");
  }
  if (!/[^A-Za-z0-9]/.test(password)) {
    errors.push("Password must contain at least one special character");
  }

  // 3. Common-password denylist
  if (COMMON_PASSWORDS.has(password.toLowerCase())) {
    errors.push("Password is too common; please choose a stronger one");
  }

  // 4. Reject if password contains the email username (basic check)
  if (email) {
    const username = email.split("@")[0]?.toLowerCase();
    if (username && username.length >= 3 && password.toLowerCase().includes(username)) {
      errors.push("Password must not contain your email username");
    }
  }

  // 5. Reject trivially repetitive / sequential patterns
  if (/^(.)\1+$/.test(password)) {
    errors.push("Password must not consist of a single repeated character");
  }

  return { valid: errors.length === 0, errors };
};
