# Voyager Chat

A cross-platform enterprise chat application built with **Flutter** and **Node.js Express**, featuring Brevo transactional email OTP authentication, Google OAuth 2.0, End-to-End Encryption (E2EE), offline BLE mesh networking, voice/video calling, AI assistance, cryptographic SHA-256 audit logging, and live operations telemetry.

---

## Architecture Overview

Voyager Chat combines a responsive Flutter client frontend with a lightweight Node.js Express backend service. It operates cleanly in both connected internet environments and offline peer-to-peer mesh topologies.

```
+-----------------------------------------------------------------------+
|                             Flutter UI                                |
|   (Login, Registration, OTP, Chat, Calls, Maps, Enterprise Settings)  |
+-----------------------------------+-----------------------------------+
                                    |
                                    v
+-----------------------------------+-----------------------------------+
|                           AuthService                                 |
|      (Brevo Email OTP, Google OAuth 2.0 PKCE, Email/Password)         |
+-----------------+---------------------------------+-------------------+
                  |                                 |
                  v                                 v
+-----------------+-----------------+     +---------+-------------------+
|      Node.js Express Backend      |     |     Local SQLite Storage        |
|  (Auth Controllers, Brevo Engine) |     |  (Messages, Audit Logs, Users)  |
+-----------------+-----------------+     +---------------------------------+
                  |
                  v
+-----------------+-----------------+
|      Brevo Email API (SMTP)       |
| (10-min OTPs, Welcome Email Delivery)|
+-----------------------------------+
```

---

## Key Features

### 1. Authentication & Onboarding
- **Email OTP Authentication (Brevo)**: Purpose-isolated OTP verification (`REGISTRATION`, `LOGIN`, `PASSWORD_RESET`) with a 10-minute expiration TTL, 60-second rate-limiting cooldown, single-use deletion, and automated Welcome Registration Email delivery. Physical delivery to recipient Gmail inbox verified via Brevo Transactional Email API.
- **Strict Anti-Bypass Rules**: Zero authenticated session creation prior to successful OTP verification.
- **Google OAuth 2.0**: Native PKCE authorization flow supporting Windows, Android, and iOS using environment-driven client IDs.
- **Email & Password**: Password authentication with SHA-256 hashing and user profile initialization.

### 2. End-to-End Encryption (E2EE) & Security
- **Identity Keys & Safety Fingerprints**: Curve25519 / Ed25519 identity key generation with 12-digit safety fingerprint verification.
- **Session Key Derivation**: HKDF SHA-256 key derivation and AES-256-GCM authenticated payload encryption.
- **Integrity & Replay Protection**: Ciphertext MAC tampering detection and sequence-number replay protection.

### 3. Mesh & Offline Transport
- **Dual Transport Manager**: Automatic routing selection between `InternetTransport` (WebSocket / Socket.IO) and `NearbyTransport` (BLE Mesh).
- **Store-and-Forward Relaying**: TTL decrementing, LRU loop prevention, and peer handshake protocol.
- **Background Sync**: Automatic pending message sync upon internet connectivity restoration (`ConnectivitySyncService`).

### 4. Voice & Video Calling
- **Signaling Infrastructure**: `CallSignalEvent` protocol handling offer, answer, ICE candidates, and active call management.
- **In-Call Controls**: Mute toggle, speaker toggle, camera on/off, camera switching, and screen sharing foundation abstraction.
- **Call History**: SQLite call log tracking duration, direction, timestamp, and participant details.

### 5. Location Services & Maps
- **GPS & Live Sharing**: Permission management, location formatting, and live stream location sharing with configurable expiration.
- **Encrypted Location Packets**: E2EE location payload encryption relayed over BLE Mesh without intermediate node decryption.
- **Map Integration**: `MapServerConfig` abstraction for MapTiler API Key security and MapLibre tile style URL formatting.

### 6. Enterprise Governance & Audit Logs
- **SHA-256 Cryptographic Hash Chaining**: Formed hash chain (`sha256(id:eventType:userId:detailsJson:timestampStr:prevHash)`) preventing log tampering.
- **Automated Tamper Detection**: `EnterpriseAuditService.instance.verifyAuditChain()` recalculates hashes across stored logs to detect modifications.
- **Sensitive Data Redaction**: Automatic redaction of passwords, OTP codes, and API keys with `[REDACTED]`.
- **Retention & Remote Wipe**: Configurable 30-day retention policies and secure remote wipe execution.

### 7. Operations & Telemetry Monitoring
- **Real Memory & DB Telemetry**: Measures process RSS memory (`ProcessInfo.currentRss`), dynamic SQLite page-size calculations (`PRAGMA page_count` * `PRAGMA page_size`), and real database integrity (`PRAGMA integrity_check`).
- **Live Monitoring UI**: 3-second auto-refresh timer in `OperationsMonitoringScreen` with lifecycle `dispose()` cleanup.
- **Crash Recovery & Maintenance**: Uncaught error capturing (`FlutterError.onError` & `PlatformDispatcher.instance.onError`) and non-blocking database maintenance (`PRAGMA wal_checkpoint(FULL)` + `VACUUM`).

### 8. AI Assistant & RAG Integration
- **AI Provider Abstraction**: `AiAssistantService` supporting `cloudGemini`, `localOllama`, and `localRuleEngine` providers.
- **Smart Replies**: Dynamic suggestion generation with fallback execution chain.

---

## Technology Stack

| Layer | Technology | Version |
| :--- | :--- | :--- |
| **Frontend Framework** | Flutter SDK | `^3.13.0` |
| **Frontend Language** | Dart | `^3.13.0` |
| **Client Router** | `go_router` | `^17.5.0` |
| **Local Database** | `sqflite` / `sqflite_common_ffi` | `^2.4.3` |
| **HTTP Client** | `dio` / `http` | `^5.11.0` / `^1.2.0` |
| **Cryptography** | `crypto` | `^3.0.6` |
| **Backend Runtime** | Node.js (CommonJS) | `>=18.0.0` |
| **Backend Framework** | Express | `^5.2.1` |
| **Realtime Engine** | Socket.IO | `^4.8.3` |
| **Email Service** | Brevo Transactional Email API | `v3/smtp/email` |

---

## Project Structure

```
Voyager-Chat/
├── backend/
│   ├── src/
│   │   ├── config/
│   │   │   └── env.js
│   │   ├── controllers/
│   │   │   └── auth.controller.js
│   │   ├── routes/
│   │   │   └── auth.routes.js
│   │   ├── services/
│   │   │   └── brevo.service.js
│   │   ├── app.js
│   │   └── server.js
│   ├── .env (gitignore)
│   └── package.json
├── frontend/
│   ├── android/
│   ├── ios/
│   ├── windows/
│   ├── lib/
│   │   ├── core/
│   │   │   ├── ai/
│   │   │   ├── auth/
│   │   │   ├── database/
│   │   │   ├── enterprise/
│   │   │   ├── location/
│   │   │   ├── meetings/
│   │   │   ├── operations/
│   │   │   ├── storage/
│   │   │   ├── theme/
│   │   │   ├── transport/
│   │   │   └── widgets/
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   ├── calling/
│   │   │   ├── chat/
│   │   │   ├── groups/
│   │   │   ├── home/
│   │   │   ├── location/
│   │   │   ├── media/
│   │   │   ├── meetings/
│   │   │   ├── search/
│   │   │   ├── settings/
│   │   │   ├── splash/
│   │   │   ├── storage/
│   │   │   ├── users/
│   │   │   └── welcome/
│   │   └── main.dart
│   ├── test/
│   │   ├── otp_parity_test.dart
│   │   ├── phase15_enterprise_telemetry_test.dart
│   │   ├── phase16_brevo_otp_welcome_test.dart
│   │   └── ... (20 phase test suites)
│   └── pubspec.yaml
├── .gitignore
└── README.md
```

---

## Environment Variables Configuration

> [!IMPORTANT]
> All backend API keys and secrets must remain strictly in `backend/.env`. Never place credentials in client source code, Flutter UI, or Git.

### Backend (`backend/.env`)
```ini
PORT=3000
BREVO_API_KEY=your_brevo_api_key_here
```

### Frontend Build Flags (`--dart-define`)
```bash
flutter run -d windows \
  --dart-define=GOOGLE_CLIENT_ID=your_windows_google_client_id \
  --dart-define=GOOGLE_CLIENT_SECRET=your_windows_google_client_secret \
  --dart-define=GOOGLE_CLIENT_ID_ANDROID=your_android_google_client_id \
  --dart-define=GOOGLE_CLIENT_ID_IOS=your_ios_google_client_id
```

---

## Installation & Setup

### Prerequisites
- Flutter SDK `^3.13.0`
- Node.js `>=18.0.0`
- Git

### 1. Repository Setup
```bash
git clone https://github.com/Themonsterk9/Voyager-Chat.git
cd Voyager-Chat
```

### 2. Backend Dependencies & Launch
```bash
cd backend
npm install
npm run dev
```

### 3. Frontend Dependencies & Launch
```bash
cd ../frontend
flutter pub get
flutter run -d windows
```

---

## Testing & Verification

The project includes an extensive test suite covering all functional phases:

```bash
cd frontend

# Run static analyzer
flutter analyze

# Run complete test suite (131 tests)
flutter test
```

### Verification Benchmarks
- **`flutter analyze`**: **0 errors, 0 warnings**
- **`flutter test`**: **131 / 131 unit and widget tests passed (100%)**

---

## Security Practices

- **Zero Hardcoded Secrets**: All API keys and secrets are loaded dynamically via environment variables or backend configurations.
- **Database Redaction**: Passwords, OTP tokens, and bearer keys are redacted (`[REDACTED]`) before entering audit log tables.
- **Single-Use OTP & Expire Policy**: OTPs expire in 10 minutes and are deleted immediately upon successful verification.
- **Cryptographic Chaining**: SHA-256 hash chaining guarantees tamper evidence across enterprise audit records.

---

## License

Distributed under the ISC License. See `backend/package.json` for details.
