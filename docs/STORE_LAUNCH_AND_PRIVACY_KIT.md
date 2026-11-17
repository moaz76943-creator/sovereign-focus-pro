# Google Play Store Launch, Privacy & Compliance Kit — Focus Studio Pro

## 1. Data Safety & Privacy Declaration (Google Play Compliant)
- **Data Collection:** Zero personal user data is collected, transmitted, or sold to third parties.
- **Offline-First Storage:** All flashcards, FSRS-4.5 review histories, tasks, notes, and focus analytics are stored locally in the device's SQLite database (`focus_studio_pro.db`).
- **Backups:** User-initiated exports use authenticated `AES-256-GCM` encryption (`PBKDF2-HMAC-SHA256`, 60,000 iterations).
- **Permissions Justification:**
  - `android.speech.tts.TextToSpeech.Engine` query: Used solely to discover installed offline on-device Android speech synthesis voices across the 100 supported languages.

## 2. Intellectual Property & Audio Copyright Provenance
- **Ambient Soundscapes:** 100% mathematically synthesized at runtime via `ProceduralSoundEngine` (rain, campfire embers, forest breeze, ocean waves, water drops, 40Hz/10Hz binaural synthesis).
- **Third-Party Audio Assets:** **0 files**. Zero risk of copyright strikes or DMCA claims on Google Play or Apple App Store.

## 3. Release Verification Checklist
- [x] Target SDK 35 (Android 15) with hardware `WindowInsetsCompat.Type.systemBars()` and 120Hz display mode.
- [x] 100 languages verified (`locales/registry_100.json`, excluding Hebrew, Western digits `0-9`).
- [x] Pre-commit & CI Secret Shield (`tools/pre_commit_shield.py` + `Gitleaks`).
- [x] Automated `app-release.aab` (Google Play) and `app-release.apk` (direct device install) artifacts.
