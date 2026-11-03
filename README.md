# My Logan

Personal Android car companion for a 2013 Dacia Logan in Morocco.

**Specification:** [MY_LOGAN_SPEC.md](MY_LOGAN_SPEC.md)  
**TomTom nav:** [docs/TOMTOM.md](docs/TOMTOM.md)  
**Release:** [docs/RELEASE.md](docs/RELEASE.md)

## Current status

- **Car records:** Dashboard, Fuel, Garage, Reminders (SQLite, offline).
- **Navigation prototype:** TomTom raster map + GPS + Morocco search + traffic-aware routing (needs API key).

## TomTom key (required for live map)

Never commit the key. Inject at build/run time:

```powershell
. .\scripts\setup-android-env.ps1
flutter build apk --release --dart-define=TOMTOM_API_KEY=YOUR_KEY
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Stay inside TomTom free monthly quotas. Do not enable paid overage without approval.

## Setup

```powershell
. .\scripts\setup-android-env.ps1
flutter pub get
flutter analyze
flutter test
```
