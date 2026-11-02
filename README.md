# My Logan

Personal Android car companion for a 2013 Dacia Logan in Morocco.

**Specification:** [MY_LOGAN_SPEC.md](MY_LOGAN_SPEC.md)  
**Feasibility (Milestone 0):** [docs/FEASIBILITY.md](docs/FEASIBILITY.md)

## Current status

Milestone 0 complete: Flutter Android skeleton + feasibility report.  
Navigation SDK and car-record features are **not** implemented yet.

## Requirements

- Flutter 3.35.1+ (verified with 3.41.6)
- Android SDK with API 27+ device/target (Galaxy A02)
- USB debugging for on-device tests

## Setup

```powershell
. .\scripts\setup-android-env.ps1
flutter pub get
flutter analyze
flutter test
```

## Secrets

Never commit Magic Lane (or other) API tokens. See `.env.example`.
