# Auth API Documentation

All endpoints are prefixed with `/auth`.

---

## Public Endpoints

### POST `/auth/register`

Create a new user account. Password must meet the [strong password policy](#password-policy).

**Rate limit:** 15 req / 10 min per IP

**Request body:**
```json
{
  "email": "user@example.com",
  "password": "MyStr0ng!Pass99",
  "name": "Alice",
  "walletAddress": "0x..."          // optional
}
```

**Success 201:**
```json
{
  "message": "User registered successfully",
  "user": {
    "id": "...",
    "email": "user@example.com",
    "name": "Alice",
    "photoUrl": null,
    "walletAddress": "0x...",
    "totalRewards": 0
  }
}
```

**Error 422 – Validation / weak password:**
```json
{
  "code": "VALIDATION_ERROR",
  "message": "Password does not meet security requirements",
  "details": [
    "Password must be at least 12 characters long",
    "Password must contain at least one special character"
  ]
}
```

**Error 409 – Email taken:**
```json
{
  "code": "EMAIL_TAKEN",
  "message": "Email already registered"
}
```

---

### POST `/auth/login`

Authenticate with email + password and receive a JWT.

**Rate limit:** 10 req / 10 min per IP+email. Account locks for 10 min after 5 failed attempts.

**Request body:**
```json
{
  "email": "user@example.com",
  "password": "MyStr0ng!Pass99"
}
```

**Success 200:**
```json
{
  "message": "Login successful",
  "token": "eyJ...",
  "user": {
    "id": "...",
    "email": "user@example.com",
    "name": "Alice",
    "photoUrl": null,
    "walletAddress": "0x...",
    "totalRewards": 100
  }
}
```

**Error 401 – Wrong credentials (or user not found):**
```json
{
  "code": "INVALID_CREDENTIALS",
  "message": "Invalid email or password"
}
```

**Error 429 – Account locked:**
```json
{
  "code": "TOO_MANY_ATTEMPTS",
  "message": "Account temporarily locked. Please try again later."
}
```

---

### POST `/auth/google`

Sign in or sign up using a Google ID token (Google Fast Auth).

**Rate limit:** 15 req / 10 min per IP

**Request body:**
```json
{
  "idToken": "eyJ..."
}
```

**Success 200:**
```json
{
  "message": "Google login successful",
  "token": "eyJ...",
  "user": {
    "id": "...",
    "email": "user@gmail.com",
    "name": "Alice",
    "photoUrl": "https://...",
    "walletAddress": "0x...",
    "totalRewards": 0
  }
}
```

**Error 401 – Invalid token:**
```json
{
  "code": "INVALID_CREDENTIALS",
  "message": "Invalid or expired Google token"
}
```

---

### POST `/auth/forgot-password`

Request a password-reset OTP. Always returns 200 to prevent email enumeration.

**Rate limit:** 3 req / 10 min per IP

**Request body:**
```json
{
  "email": "user@example.com"
}
```

**Response 200 (always):**
```json
{
  "message": "If an account with that email exists, a password reset code has been sent."
}
```

> **Dev note:** If SMTP is not configured, the OTP is logged to the server console.

---

### POST `/auth/verify-otp`

Verify the 6-digit OTP received via email. On success, returns a one-time `resetToken`.

**Rate limit:** 5 req / 10 min per IP. OTP is invalidated after 5 failed attempts.

**Request body:**
```json
{
  "email": "user@example.com",
  "otp": "482910"
}
```

**Success 200:**
```json
{
  "message": "OTP verified successfully",
  "resetToken": "a3f9c2..."
}
```

**Error 400 – Invalid / expired OTP:**
```json
{
  "code": "INVALID_OTP",
  "message": "Invalid or expired OTP"
}
```

**Error 400 – OTP expired:**
```json
{
  "code": "OTP_EXPIRED",
  "message": "OTP has expired. Please request a new code."
}
```

**Error 429 – Too many attempts:**
```json
{
  "code": "TOO_MANY_ATTEMPTS",
  "message": "Too many OTP attempts. Please request a new code."
}
```

---

### POST `/auth/reset-password`

Set a new password using the `resetToken` from `/auth/verify-otp`. Password must meet the [strong password policy](#password-policy).

**Rate limit:** 5 req / 10 min per IP

**Request body:**
```json
{
  "email": "user@example.com",
  "resetToken": "a3f9c2...",
  "newPassword": "N3wSecure!Pass"
}
```

**Success 200:**
```json
{
  "message": "Password reset successfully"
}
```

**Error 422 – Weak password:**
```json
{
  "code": "VALIDATION_ERROR",
  "message": "Password does not meet security requirements",
  "details": ["..."]
}
```

**Error 400 – Invalid token:**
```json
{
  "code": "INVALID_TOKEN",
  "message": "Invalid or expired reset token"
}
```

---

## Protected Endpoints

All protected endpoints require the header:
```
Authorization: Bearer <jwt>
```

### GET `/auth/me`

Get the current authenticated user's profile.

**Success 200:**
```json
{
  "user": {
    "id": "...",
    "email": "user@example.com",
    "name": "Alice",
    "photoUrl": null,
    "walletAddress": "0x...",
    "totalRewards": 100,
    "createdAt": "2026-01-15T12:00:00.000Z"
  }
}
```

### PUT `/auth/me`

Update the current user's profile fields.

**Request body (all optional):**
```json
{
  "name": "Alice B.",
  "walletAddress": "0x...",
  "photoUrl": "https://..."
}
```

**Success 200:**
```json
{
  "message": "User updated successfully",
  "user": { ... }
}
```

---

## Password Policy

Enforced on `POST /auth/register` and `POST /auth/reset-password`:

| Rule | Requirement |
|------|-------------|
| Minimum length | 12 characters |
| Uppercase | At least 1 |
| Lowercase | At least 1 |
| Number | At least 1 |
| Special character | At least 1 |
| Common passwords | Rejected (denylist) |
| Username in password | Rejected (email username) |
| Repeated characters | Rejected (e.g. `aaaaaaaaaaaa`) |

---

## Error Code Reference

| HTTP | Code | When |
|------|------|------|
| 401 | `INVALID_CREDENTIALS` | Wrong email/password or invalid Google token |
| 403 | `EMAIL_NOT_VERIFIED` | Email not yet verified (reserved) |
| 409 | `EMAIL_TAKEN` | Registration with existing email |
| 422 | `VALIDATION_ERROR` | Missing fields or weak password |
| 429 | `TOO_MANY_ATTEMPTS` | Rate limit or account lockout |
| 400 | `INVALID_OTP` | Wrong or missing OTP |
| 400 | `OTP_EXPIRED` | OTP past expiry window |
| 400 | `INVALID_TOKEN` | Wrong or missing reset token |

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_SECRET` | **Yes** | Secret for signing JWTs |
| `MONGODB_URI` | **Yes** | MongoDB connection string |
| `GOOGLE_CLIENT_ID` | No* | Google OAuth2 client ID |
| `GOOGLE_CLIENT_IDS` | No | Comma-separated additional audience IDs |
| `SMTP_HOST` | No** | SMTP server host |
| `SMTP_PORT` | No** | SMTP port (465 / 587) |
| `SMTP_USER` | No** | SMTP username |
| `SMTP_PASS` | No** | SMTP password |
| `SMTP_FROM` | No | From address (default: `noreply@recycleapp.local`) |

\* Required if Google sign-in is used.  
\** If not set, OTPs are logged to the console (dev-only).
