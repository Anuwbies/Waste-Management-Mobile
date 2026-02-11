# API Frontend Contract

> Auto-generated reference for frontend integration.
> Backend base URL: `http://<host>:5000`
> All `/waste/*` and `/rewards/*` routes require `Authorization: Bearer <JWT>`.

---

## Authentication

### POST /auth/register

**Request:**
```json
{ "email": "user@example.com", "password": "P@ssw0rd!", "name": "Jane" }
```

**201 Created:**
```json
{
  "message": "User registered successfully",
  "user": { "id": "665f...", "email": "user@example.com", "name": "Jane" }
}
```

### POST /auth/login

**Request:**
```json
{ "email": "user@example.com", "password": "P@ssw0rd!" }
```

**200 OK:**
```json
{
  "message": "Login successful",
  "token": "eyJhbGci...",
  "user": {
    "id": "665f...",
    "email": "user@example.com",
    "name": "Jane",
    "photoUrl": null,
    "walletAddress": "",
    "totalRewards": 0
  }
}
```

**401:** `{ "message": "Invalid email or password" }`

---

## Waste Classification

### POST /waste/upload

Upload an image for AI classification. The image is stored and a classification record is persisted.

**Request:** `multipart/form-data`
| Field   | Type   | Required | Notes |
|---------|--------|----------|-------|
| `image` | file   | yes      | JPEG, PNG, WebP, or HEIC. Max 10 MB. |

**201 Created (approved):**
```json
{
  "message": "Image uploaded and classified successfully",
  "classification": {
    "id": "665f...",
    "imageUrl": "/uploads/waste-1723456789-123456789.jpg",
    "wasteType": "plastic",
    "confidence": 0.923456,
    "rawLabel": "Plastic",
    "modelVersion": "final_model.tflite",
    "topK": [
      { "label": "Plastic",   "canonicalLabel": "plastic", "score": 0.923456 },
      { "label": "Glass",     "canonicalLabel": "glass",   "score": 0.041230 },
      { "label": "Paper",     "canonicalLabel": "paper",   "score": 0.018900 }
    ],
    "rewardPoints": 5,
    "status": "approved"
  },
  "totalRewards": 25
}
```

**201 Created (denied — low confidence or unknown type):**
```json
{
  "message": "Image classified but reward denied (low confidence or unsupported type)",
  "classification": {
    "id": "665f...",
    "imageUrl": "/uploads/waste-1723456789-123456789.jpg",
    "wasteType": "unknown",
    "confidence": 0.210000,
    "rawLabel": "Automobile",
    "modelVersion": "final_model.tflite",
    "topK": [ ... ],
    "rewardPoints": 0,
    "status": "denied"
  },
  "totalRewards": 25
}
```

**Error responses:**
| Status | Condition | Body |
|--------|-----------|------|
| 400    | No file attached | `{ "message": "No image file uploaded" }` |
| 415    | Invalid file type | `{ "message": "Invalid file type. Only JPEG, PNG, WebP, and HEIC are allowed." }` |
| 503    | AI service down | `{ "message": "AI classification service is unavailable. Please try again later.", "error": "..." }` |

### POST /waste/classify

Preview-only classification. Image is NOT stored. Same contract as `/waste/upload` but returns `potentialRewardPoints` instead of persisting.

**200 OK:**
```json
{
  "wasteType": "metal",
  "confidence": 0.874,
  "rawLabel": "Metal",
  "modelVersion": "final_model.tflite",
  "topK": [ ... ],
  "potentialRewardPoints": 8,
  "status": "approved"
}
```

### POST /waste/suggestion

Get disposal suggestions for a classified waste type.

**Request:**
```json
{ "wasteType": "plastic", "confidence": 0.92 }
```

**200 OK:**
```json
{
  "binType": "Blue Recycling Bin",
  "steps": ["Remove any food residue", "Rinse the container if possible", ...],
  "warnings": ["No plastic bags in recycling bin", ...],
  "tips": ["Check the recycling symbol", ...],
  "localRules": null,
  "isRecyclable": true,
  "impactMessage": "Recycling one plastic bottle saves enough energy..."
}
```

### GET /waste/history?page=1&limit=20

**200 OK:**
```json
{
  "classifications": [
    {
      "_id": "665f...",
      "userId": "664a...",
      "imageUrl": "/uploads/waste-...",
      "wasteType": "plastic",
      "confidence": 0.92,
      "rewardPoints": 5,
      "rawLabel": "Plastic",
      "modelVersion": "final_model.tflite",
      "status": "approved",
      "createdAt": "2026-02-11T10:30:00.000Z",
      "updatedAt": "2026-02-11T10:30:00.000Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 42,
    "totalPages": 3
  }
}
```

> **Note:** History records returned via `.lean()` use `_id` (not `id`).
> Frontend must handle both `json['id']` and `json['_id']`.

### GET /waste/:id

**200 OK:**
```json
{
  "classification": { "_id": "665f...", "wasteType": "glass", ... }
}
```

---

## Rewards

### GET /rewards/balance

**200 OK:**
```json
{
  "balance": 120,
  "chainStats": { "balance": "120", "totalRecycled": "15", "chainId": 31337 }
}
```

### GET /rewards/history?page=1&limit=20

**200 OK:**
```json
{
  "history": [ { "type": "classification", "points": 5, "description": "...", ... } ],
  "pagination": { "page": 1, "limit": 20, "total": 10, "totalPages": 1 }
}
```

---

## Health

### GET /health
`{ "status": "ok" }`

### GET /health/ai
```json
{
  "ok": true,
  "latencyMs": 42,
  "status": "ok",
  "modelLoaded": true,
  "modelVersion": "final_model.tflite",
  "classCount": 9,
  "inputSize": [260, 260]
}
```

### GET /health/blockchain
```json
{ "ok": true, "chainId": 31337, "contractAddress": "0x...", "blockNumber": 123 }
```

---

## Canonical Waste Types

The system uses 6 canonical waste types plus `unknown`:

| Canonical    | Reward Points | Model Raw Labels           |
|-------------|---------------|----------------------------|
| `plastic`   | 5             | Plastic                    |
| `paper`     | 4             | Paper                      |
| `metal`     | 8             | Metal, Automobile          |
| `glass`     | 6             | Glass                      |
| `organic`   | 3             | Organic                    |
| `e-waste`   | 15            | E-waste, Battery, Light Bulb |
| `unknown`   | 0             | (fallback for unmapped)    |

### Reward Denial Rules

Rewards are set to 0 and status is `"denied"` when:
- `wasteType === "unknown"`
- `confidence < 0.40` (40% threshold)
- `wasteType` is not in the rewardable set

---

## Image Access

Uploaded images are served as static files:
```
GET http://<host>:5000/uploads/waste-1723456789-123456789.jpg
```
No authentication required for static image access.

---

## Error Format

All errors follow:
```json
{ "message": "Human-readable error description" }
```

Optional fields: `error` (technical detail), `existingLog` (for 409 duplicates).
