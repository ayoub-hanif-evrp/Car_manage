# My Logan

Personal Android car companion for a 2013 Dacia Logan in Morocco.

**Specification:** [MY_LOGAN_SPEC.md](MY_LOGAN_SPEC.md)  
**Navigation:** [docs/NAVIGATION_BLOCKER.md](docs/NAVIGATION_BLOCKER.md)  
**Release:** [docs/RELEASE.md](docs/RELEASE.md)

## Current status

- **Car records:** Dashboard, Fuel, Garage, Reminders (SQLite, offline).
- **Navigation prototype:** MapLibre + OpenFreeMap + public OSRM (no API keys).  
  ETA is **not** live traffic.

## Setup

Requires **JDK 21** for MapLibre Android builds.

```powershell
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
. .\scripts\setup-android-env.ps1
flutter pub get
flutter analyze
flutter test
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

## Attribution

Map: © OpenFreeMap · © OpenStreetMap contributors  
Routing: OSRM / FOSSGIS public demo (personal testing only)
