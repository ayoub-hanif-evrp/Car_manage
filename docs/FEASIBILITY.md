# My Logan — Milestone 0 Feasibility Report

**Date:** 2026-11-02  
**Status:** Environment skeleton complete; navigation provider gates **unresolved**  
**Source of truth:** [MY_LOGAN_SPEC.md](../MY_LOGAN_SPEC.md)

## Owner constraints (locked)

- Strictly personal use (one driver, one phone).
- Budget: **0 MAD/month** ongoing cost.
- Morocco **live traffic** is essential (traffic-aware routes and ETA).
- Target device: Samsung Galaxy A02 (low-end); performance is a hard priority.
- No features beyond the spec.

## Development environment (checked)

| Item | Result |
|---|---|
| Flutter | 3.41.6 stable — OK for Magic Lane (requires ≥ 3.35.1) |
| Dart | 3.11.4 — OK (requires ≥ 3.9.0) |
| Android SDK | 36.1.0 at `%LOCALAPPDATA%\Android\Sdk` |
| Android licenses | Accepted during Milestone 0 |
| `adb` | Works when `platform-tools` is on PATH |
| Galaxy A02 | **Not connected** at Milestone 0 close |
| Visual Studio (Windows desktop) | Missing — irrelevant for Android-only app |
| Project | Flutter Android-only app `com.meinloga.my_logan`, `minSdk = 27` |
| `flutter analyze` | Passed (no issues) |
| `flutter test` | Passed (placeholder widget test) |
| `flutter build apk --debug` | **Not verified** — first Gradle `assembleDebug` ran 20+ minutes with no progress output and was stopped. Owner should re-run locally after permanent `ANDROID_HOME`/PATH setup. |

### Persistent PATH note

This shell session can set `ANDROID_HOME` temporarily. For new terminals, set user environment variables:

- `ANDROID_HOME` = `C:\Users\Emsi\AppData\Local\Android\Sdk`
- Add to PATH: `%ANDROID_HOME%\platform-tools`

Or run [scripts/setup-android-env.ps1](../scripts/setup-android-env.ps1) in a PowerShell session before Flutter/Android commands.

## Navigation provider: Magic Lane (primary candidate)

Package under consideration for Milestone 1: `magiclane_maps_flutter` (latest checked: 3.1.14).  
**Not added to the project in Milestone 0.**

### Documented strengths

- Flutter-native map, search, car routing, turn-by-turn, rerouting callbacks, camera follow.
- Traffic-aware route preferences and better-route APIs exist in docs.
- Custom Darija clips are feasible by disabling SDK TTS and playing local audio from maneuver events.
- Offline maps available; live traffic requires connectivity.

### Unresolved risk: cost vs 0 MAD/month

- Free trial / free operations exist for evaluation. **Trial is not permanent free production use.**
- Public pricing describes a **one-off lifetime license + annual maintenance** with **no published amounts**.
- Expired API keys can watermark / limit features.
- **Gate:** Owner must get **written** confirmation of a production path that costs **0 MAD/month**, or stop. Do not ship on a forever-trial assumption.

### Unresolved risk: Morocco live traffic (essential)

- Magic Lane SDK docs claim real-time traffic but also state traffic may vary by region.
- Better-route detection requires active traffic on the route.
- Magic Earth (same company product) published live-traffic country list: Africa = **South Africa only**. **Morocco is not listed.**
- **Gate:** Treat SDK Morocco traffic as **unverified** until demonstrated on-device in Casablanca during Milestone 1, or confirmed in writing by Magic Lane. OSM/offline routing alone is **not** live traffic.

### Unresolved risk: Galaxy A02 performance

- Public device profile: Android 10→11, MediaTek MT6739W, PowerVR GE8100, 2–4 GB RAM.
- Meets API 27 minimum; GPU/RAM are weak for continuous navigation rendering.
- Magic Lane docs warn that lower-end devices may see reduced smoothness.
- **Gate:** Only release-APK measurements on the physical A02 count. Confirm Android version and RAM on device.

## Google Navigation SDK — not an automatic fallback

Google documents Morocco traffic coverage and a monthly free destination allotment, but its **published policy restricts use to commercial applications**.

Because this app is strictly personal:

- Google Navigation is **not** an automatic fallback.
- Do **not** integrate it unless the owner later obtains **appropriate written permission** for this personal use and explicitly re-approves after a stop-gate review.

## Other providers (not selected)

| Provider | Why not selected now |
|---|---|
| Mapbox Navigation | Vehicle-in-app commercial license risk; cost not 0 MAD/month by default |
| HERE Navigate | Contract / commercial edition |
| TomTom | Typically commercial |
| OSRM / public OSM alone | **Not** real-time traffic — forbidden by spec |

## Milestone 1 pass/fail criteria (when authorized)

All must pass:

1. Real online route + ETA from provider (not hardcoded).
2. **Live traffic effect on ETA/route demonstrated in Casablanca**, or written Magic Lane confirmation of Morocco live traffic.
3. Acceptable A02 smoothness on a **release** APK (20–30 minute real test).
4. Legal/production path compatible with **0 MAD/month** (or stop).

Any failure → stop and report trade-offs. No fake traffic. No automatic provider switch.

## Secrets handling (for later milestones)

- Magic Lane API token must **never** be committed.
- Planned injection for Milestone 1: `--dart-define=MAGIC_LANE_TOKEN=...`
- See `.env.example` for local documentation only.

## Manual owner actions still required

1. Set permanent `ANDROID_HOME` / PATH (or use the setup script each session).
2. Connect Galaxy A02 with USB debugging; report Android version and RAM.
3. Create a Magic Lane developer account and trial API key (for Milestone 1 only when approved).
4. Contact Magic Lane in writing: (a) free personal production for one Android app at 0 MAD/month? (b) Morocco live traffic coverage?
5. Optional signal check: Magic Earth traffic layer in Casablanca (not SDK proof).
6. Approve Milestone 1 before any navigation SDK code is added.

## Milestone 0 deliverables

- Flutter Android project skeleton (`my_logan`)
- Git repository + `.gitignore` (secrets excluded)
- `minSdk = 27`, app label **My Logan**
- Placeholder UI only (no map / no car modules)
- This feasibility report

## Explicitly not done in Milestone 0

- Magic Lane (or any) navigation SDK integration
- Destination search, routing, traffic, voice, favorites
- Fuel / garage / reminders / dashboard
- Release performance testing on Galaxy A02
