# Autonomous Engineering Constitution
1. Modular isolation: Android 15 shell, SQLite WAL DB, AES-256-GCM Backup, FSRS-4.5, Active Recall, Native TTS, CC0 Nature Audio + Native AudioTrack, UI features, and 100-language locales live in separate modules.
2. Zero secrets in git; Gitleaks and `tools/pre_commit_shield.py` must pass on every commit.
3. 100 languages (strictly excluding Hebrew `he`/`iw`), Western digits (`0-9`) for all numbers, explicit separation between UI translation availability and device TTS voice availability.
4. Calm AMOLED (`#000000`) 120Hz design with zero text truncation and full RTL/LTR bidirectional isolation.
