# Release APK — My Logan

## Personal sideload (current)

`android/app/build.gradle.kts` signs **release** with the **debug** keystore so you can install a release build on your Galaxy A02 without creating a Play Store keystore.

```powershell
. .\scripts\setup-android-env.ps1
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Use release (not debug) for any navigation performance judgment once Magic Lane gates clear.

## Optional: your own keystore later

1. Create a keystore (keep it offline; never commit it).
2. Add `android/key.properties` (gitignored) with `storePassword`, `keyPassword`, `keyAlias`, `storeFile`.
3. Wire `signingConfigs.release` in `build.gradle.kts` and point `buildTypes.release.signingConfig` at it.

## Feature checklist (A02)

- [ ] Dashboard month totals + chart after adding fuel/repairs
- [ ] Fuel add/edit/delete; odometer validation; full-to-full consumption when 2 pleins exist
- [ ] Garage add/edit/delete
- [ ] Reminders: date notify, oil interval renew, odometer crossing notify after fuel save
- [ ] Favorites add/edit/delete on Navigation tab
- [ ] Darija test button: fails quietly until owner `.mp3` files exist
- [ ] Navigation tab still shows blockers (no fake map/ETA)

## Still blocked

Live map / traffic / turn-by-turn / Darija event wiring — see [NAVIGATION_BLOCKER.md](NAVIGATION_BLOCKER.md).
