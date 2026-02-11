# Firebase to REST API Migration Guide

This document outlines the migration from Firebase to a custom REST API backend for the Waste Sorting and Recycling Reward System.

## Overview

The Flutter mobile app has been migrated from Firebase (Auth + Firestore + Storage) to communicate with an Express/Node.js backend via HTTP REST APIs.

## Architecture Changes

### Before (Firebase)
```
Flutter App → Firebase Auth → Firebase Firestore → Firebase Storage
```

### After (REST API)
```
Flutter App → HTTP/REST → Express Backend → MongoDB → (Optional: Blockchain)
```

## Backend API Endpoints

### Authentication (`/auth`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/auth/register` | Register new user | No |
| POST | `/auth/login` | Login with email/password | No |
| POST | `/auth/google` | Login with Google OAuth | No |
| GET | `/auth/me` | Get current user profile | Yes |
| PUT | `/auth/me` | Update current user profile | Yes |

### Waste Classification (`/waste`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/waste/upload` | Upload & classify waste image | Yes |
| POST | `/waste/classify` | Classify without storing (preview) | Yes |
| GET | `/waste/history` | Get classification history | Yes |
| GET | `/waste/:id` | Get single classification | Yes |

### Recycling (`/recycle`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/recycle` | Log recycling activity | Yes |
| GET | `/recycle/logs` | Get recycling logs | Yes |

### Rewards (`/rewards`)

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| GET | `/rewards/balance` | Get reward balance | Yes |
| GET | `/rewards/history` | Get reward history | Yes |
| GET | `/rewards/stats` | Get reward statistics | Yes |

## Flutter Services

### ApiClient (`lib/services/api_client.dart`)
Centralized HTTP client with:
- JWT token management via `flutter_secure_storage`
- Automatic auth header injection
- Error handling and response parsing
- File upload support (multipart/form-data)

### AuthService (`lib/services/auth_service.dart`)
Handles:
- User registration
- Email/password login
- Google OAuth (token exchange with backend)
- User profile management
- Token validation and refresh

### WasteService (`lib/services/waste_service.dart`)
Handles:
- Image upload and classification
- Classification preview (without storage)
- Classification history retrieval

### RecyclingService (`lib/services/recycling_service.dart`)
Handles:
- Logging recycling activities
- Retrieving recycling logs

### RewardsService (`lib/services/rewards_service.dart`)
Handles:
- Fetching reward balance
- Reward history
- Reward statistics

## Setup Instructions

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Copy and configure environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

4. Required environment variables:
   ```env
   PORT=5000
   MONGODB_URI=mongodb://localhost:27017/waste_recycling
   JWT_SECRET=your-super-secret-jwt-key
   GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
   ```

5. Start the server:
   ```bash
   npm run dev
   ```

### Flutter Setup

1. Navigate to the Flutter directory:
   ```bash
   cd Waste-Management-Mobile
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure API base URL in `lib/services/api_client.dart`:
   - Android Emulator: `http://10.0.2.2:5000`
   - iOS Simulator: `http://localhost:5000`
   - Physical device: `http://<your-ip>:5000`
   - Production: `https://your-api-domain.com`

4. Run the app:
   ```bash
   flutter run
   ```

## Authentication Flow

### Email/Password Registration
1. User submits registration form
2. Flutter sends POST to `/auth/register`
3. Backend hashes password and creates user in MongoDB
4. User redirected to login page

### Email/Password Login
1. User submits login form
2. Flutter sends POST to `/auth/login`
3. Backend verifies credentials and returns JWT
4. Flutter stores JWT securely
5. User redirected to home page

### Google Sign-In
1. User taps "Sign in with Google"
2. Flutter initiates Google OAuth flow
3. Google returns ID token
4. Flutter sends ID token to POST `/auth/google`
5. Backend verifies token with Google and returns JWT
6. Flutter stores JWT securely
7. User redirected to home page

## Security Considerations

1. **JWT Storage**: Tokens are stored using `flutter_secure_storage`
2. **Token Expiry**: JWTs expire after 7 days
3. **Password Hashing**: Using bcryptjs with 10 salt rounds
4. **Google Token Verification**: Backend verifies Google tokens before accepting

## Files Changed

### Flutter Files Modified
- `lib/main.dart` - Removed Firebase, added AuthService
- `lib/Pages/Login_Page.dart` - Uses AuthService instead of FirebaseAuth
- `lib/Pages/Register_Page.dart` - Uses AuthService instead of FirebaseAuth
- `lib/Pages/Profile_Page.dart` - Uses AuthService for user data and logout
- `lib/Pages/Scan_Page.dart` - Uses WasteService for classification
- `lib/Pages/Camera/Camera_Page.dart` - Passes file to ScanPage
- `pubspec.yaml` - Removed Firebase deps, added http and flutter_secure_storage

### Flutter Files Created
- `lib/services/api_client.dart` - Centralized HTTP client
- `lib/services/auth_service.dart` - Authentication service
- `lib/services/waste_service.dart` - Waste classification service
- `lib/services/recycling_service.dart` - Recycling logging service
- `lib/services/rewards_service.dart` - Rewards management service
- `lib/models/user_model.dart` - User data model
- `lib/models/auth_response.dart` - Auth response models
- `lib/models/waste_classification.dart` - Classification models
- `lib/models/recycling_log.dart` - Recycling log models
- `lib/models/reward_models.dart` - Reward-related models
- `lib/config/api_config.dart` - API configuration

### Backend Files Created
- `src/middleware/auth.ts` - JWT authentication middleware
- `src/controllers/authController.ts` - Authentication controller
- `src/controllers/wasteController.ts` - Waste classification controller
- `src/controllers/rewardsController.ts` - Rewards controller
- `src/routes/authRoutes.ts` - Authentication routes
- `src/routes/wasteRoutes.ts` - Waste routes
- `src/routes/rewardsRoutes.ts` - Rewards routes
- `src/models/WasteClassification.ts` - Classification model
- `src/models/RecyclingLog.ts` - Recycling log model
- `src/models/RewardHistory.ts` - Reward history model

### Backend Files Modified
- `src/index.ts` - Added new routes
- `src/models/User.ts` - Added passwordHash, googleId, photoUrl fields
- `src/controllers/recycleController.ts` - Updated to use auth middleware
- `src/routes/recycleRoutes.ts` - Added auth middleware
- `package.json` - Added new dependencies
- `.env.example` - Added JWT and Google OAuth config

## Testing

### Backend Testing
```bash
# Health check
curl http://localhost:5000/health

# Register
curl -X POST http://localhost:5000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123","name":"Test User"}'

# Login
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# Get profile (use token from login response)
curl http://localhost:5000/auth/me \
  -H "Authorization: Bearer <token>"
```

## Troubleshooting

### Common Issues

1. **Connection refused**: Make sure backend is running and using correct IP
2. **401 Unauthorized**: Token may be expired, try logging in again
3. **CORS errors**: Backend has CORS enabled, check if origin is allowed
4. **Google Sign-In fails**: Verify GOOGLE_CLIENT_ID matches in both Flutter and backend
