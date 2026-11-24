# Handelha — Google Play Store Storage, Cloud Sync & Compliance Guide

> **Scope:** Production storage architecture (`SQLite + Outbox + Firebase Auth & Firestore Subcollections Delta Sync`) and exact Play Console compliance steps required before uploading an Android App Bundle (`.aab`) to Google Play.

---

## 1. Storage Architecture Overview

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Local Primary DB** | `sqflite` (`handelha_workspace_v1.db`, WAL mode, foreign keys ON) | Normalized `tasks`, `projects`, `project_phases`, `focus_sessions`, `sync_outbox`, `sync_cursors`, `schema_migrations` |
| **Legacy Upgrade** | Atomic transaction (`migrateLegacyJsonIfNeeded`) | Migrates legacy `local_*_v1` JSON blobs with pre-migration encrypted backup (`legacy_pre_sqlite_backup_v1`) and row-count verification |
| **Secrets & Session** | `flutter_secure_storage` (Android Keystore) | Auth tokens, salted PBKDF2-HMAC-SHA256 (`100,000` iterations in Isolate), local guest ID |
| **Android Backup Protection** | `android:allowBackup="false"` + `data_extraction_rules.xml` | Blocks unencrypted Google Auto Backup / D2D transfer of local DB & shared preferences |
| **Cloud Sync (Optional)** | `CloudSyncEngine` -> `FirebaseSubcollectionSyncGateway` | Per-entity delta sync under `users/{uid}/tasks`, `users/{uid}/projects`, `users/{uid}/focus_sessions` with exponential backoff (`30s..3600s`) and UTC `updated_at` conflict resolution |
| **Zero-Friction Start** | `local_<uuid>` workspace | Users can start immediately without an account and upgrade later with automatic workspace migration |

---

## 2. Google Play Data Safety Form Mapping

Choose the column that matches the build flags you ship to Google Play:

| Play Data Safety Question | Local-Only Release (no Firebase `--dart-define`) | Cloud Sync Release (`FIREBASE_API_KEY` + `FIREBASE_PROJECT_ID`) |
| :--- | :--- | :--- |
| Does your app collect or share required user data? | **No** (all tasks, projects, focus sessions, and telemetry remain on-device unless user explicitly exports JSON) | **Yes** — collected for **App functionality & Account management** only; **Never shared with third parties for ads** |
| Personal Info — Email address & Name | Not collected off-device | **Collected** (Optional — user can use local guest mode without account). Encrypted in transit (HTTPS/TLS). |
| App Activity / User-Generated Content (Tasks, Projects, Focus sessions) | On-device only | **Collected** (Optional — synced only when user signs in to a cloud account). Encrypted in transit (TLS) and at rest (Google Cloud KMS). |
| Financial Info / Purchase History | Only if RevenueCat/Google Play Billing is configured | **Collected** by Google Play Billing / RevenueCat solely for subscription entitlement verification. |
| Audio / Microphone | Processed via Android system Speech-to-Text on user tap (with explicit first-tap disclosure); Handelha does not upload or store raw audio. | Same — Handelha stores zero raw audio recordings on its servers. |
| Data Deletion Request | Supported in-app (**Settings -> Delete Account**) — clears all local SQLite tables, outbox, and secure storage immediately. | Supported in-app (**Settings -> Delete Account** -> deletes `tasks`, `projects`, `focus_sessions`, `workspaces/primary`, `users/{uid}`, and Firebase Auth account) **+ external web deletion URL required by Google Play**. |

---

## 3. Google Play Account Deletion Policy Checklist

Google Play requires any app that supports cloud account creation to provide **both**:
1. **In-app deletion path** — Implemented in `SettingsScreen` -> `AuthNotifier.deleteAccount()` -> `FirebaseCloudService.deleteUserCloudData(userId)` which deletes every document in `tasks`, `projects`, `focus_sessions`, legacy `workspaces/primary`, `users/{uid}`, and deletes the Firebase Auth user (`accounts:delete`).
2. **External web URL** (for users who uninstalled the app) — Before submitting to Play Console:
   - Publish a simple page at `https://<your-domain>/delete-account` explaining how to delete the account in-app or email support (`support@<your-domain>`) for deletion within 7 days.
   - Enter that URL in **Google Play Console -> App content -> Data safety -> Account deletion**.

---

## 4. Firebase Console Production Setup Checklist

> **Status:** `لم يُشغّل` (Requires the owner's Google/Firebase Console project & Play App Signing keys).

1. Create a production Firebase project (e.g., `handelha-prod`) on the Blaze plan with **Google Cloud Budget Alerts** (e.g., \$5 / \$15 / \$30).
2. Enable **Authentication -> Sign-in method**:
   - Email/Password
   - Google Sign-In (add **Play App Signing** SHA-1 & SHA-256 fingerprints from Play Console -> Setup -> App signing).
3. Create **Cloud Firestore** in Production Mode (region closest to Egypt, e.g., `eur3` or `europe-west1`).
4. Deploy the version-controlled security rules from this repo:
   ```bash
   firebase deploy --only firestore:rules
   ```
   Rules file: [`firebase/firestore.rules`](../firebase/firestore.rules)
5. Enable **Firebase App Check** using **Play Integrity** for Android release builds.
6. Build the release Android App Bundle with explicit production defines (never hardcode keys in source):
   ```bash
   flutter build appbundle --release ^
     --dart-define=FIREBASE_API_KEY=<YOUR_WEB_API_KEY> ^
     --dart-define=FIREBASE_PROJECT_ID=<YOUR_PROJECT_ID> ^
     --dart-define=GOOGLE_WEB_CLIENT_ID=<YOUR_WEB_CLIENT_ID> ^
     --dart-define=VERIFIED_SOCIAL_OAUTH=true ^
     --dart-define=REVENUECAT_ANDROID_API_KEY=<YOUR_RC_PUBLIC_ANDROID_KEY>
   ```
   *(Ensure `ENABLE_PREVIEW_ACCOUNT` is NEVER set in production; release builds hard-disable the preview account regardless.)*

---

## 5. Physical Android Device Reliability Verification Matrix

> **Execution Status:** `لم يُشغّل` (No physical Android OEM devices are attached to this workstation. Must be executed on real hardware before public Play Store launch.)

| Scenario | Device 1: Samsung (One UI / Android 13+) | Device 2: Xiaomi/Oppo (MIUI/HyperOS / ColorOS) | Pass Criteria |
| :--- | :--- | :--- | :--- |
| **Legacy v1 JSON -> SQLite upgrade** | `لم يُشغّل` | `لم يُشغّل` | Zero lost tasks/projects/phases/sessions; `legacy_pre_sqlite_backup_v1` created; second launch skips migration cleanly |
| **Zero-friction guest -> cloud signup** | `لم يُشغّل` | `لم يُشغّل` | Guest creates 3 tasks & 1 project -> Settings -> Link Account -> signs up -> all items appear in Firestore `users/{uid}/*` |
| **Offline edits + airplane mode + reconnect** | `لم يُشغّل` | `لم يُشغّل` | Outbox queues edits offline, backs off without crashing, drains to 0 when online |
| **Two-device conflict test** | `لم يُشغّل` | `لم يُشغّل` | Edit same task offline on Device A (t=10:00) and Device B (t=10:05) -> Device B wins cleanly without deleting other tasks |
| **Cold reboot + Doze alarm delivery** | `لم يُشغّل` | `لم يُشغّل` | Task reminder fires after device reboot and 30m Doze idle (with OEM battery guidance shown if restricted) |
| **Timezone shift (`UTC+2` -> `UTC+3`)** | `لم يُشغّل` | `لم يُشغّل` | `updated_at` UTC cursors stay monotonic; no duplicate pulls or skipped sync items |
| **Full cloud + local account deletion** | `لم يُشغّل` | `لم يُشغّل` | Settings -> Delete Account -> 0 docs left under `users/{uid}/*` in Firestore Console + local SQLite empty |
