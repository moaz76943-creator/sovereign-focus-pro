# Play Integrity Integration Guide

1. In Google Cloud Console create / use a project and enable Play Integrity API.
2. Link the project to your Play Console app.
3. Replace `YOUR_CLOUD_PROJECT_NUMBER` in the call sites.
4. In `MainActivity.java` register the MethodChannel handler that calls `IntegrityHelper`.
5. On successful token, optionally send to a Cloud Function that calls the Play Integrity decode API and returns a signed verdict.
6. Store the verified state in encrypted storage (existing cryptography package or flutter_secure_storage).

This layer + R8 + encrypted backups makes casual modding / entitlement bypass significantly harder while staying fully Play-compliant and privacy-first.
