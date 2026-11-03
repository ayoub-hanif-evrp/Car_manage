# Navigation architecture review (pre-commitment)

**Date:** 2026-11-03  
**Device target:** Samsung Galaxy A02 (SM-A022F), Android 10, ~2–3 GB RAM  
**Rule:** Do not use OSRM/Valhalla as live-traffic substitutes. Do not rewrite car-record modules.

## Executive verdict

| Question | Verdict |
|---|---|
| Is TomTom free Maps API enough for full Darija turn-by-turn? | **Not verified — likely needs separate TomTom permission** |
| Prefer MapLibre GL or `flutter_map` on A02? | **Prefer `flutter_map` (raster) until an on-device A/B proves otherwise** |
| Can we commit to deeper TomTom nav now? | **No — stop for owner review on licensing** |
| On-device map-engine benchmark run? | **`flutter_map` measured on A02; MapLibre not run (needs JDK 21)** |

---

## 1. Current architecture (already in repo)

```
Navigation tab
  ├─ if TOMTOM_API_KEY present → NavigationMapPage (flutter_map + TomTom raster)
  │     └─ NavigationSession → Geolocator + TomTomApiClient (Search + Calculate Route)
  └─ else → blocked UI + favorites / Darija checklist
Car records (Fuel / Garage / Reminders / Dashboard) stay SQLite-only, map not initialized there.
```

This is a **REST Routing + raster tiles** stack, **not** TomTom Navigation SDK.  
Automatic off-route recalculation and traffic refresh exist in `NavigationSession`.  
Darija event wiring is **not** finished (needs real maneuver events + owner MP3s).

---

## 2. Map engines compared

### A) `flutter_map` + raster tiles (current)

| Aspect | Assessment for A02 |
|---|---|
| Rendering | Pure Flutter / Skia — no Android Platform View |
| RAM | Lower fixed cost; tiles are PNG bitmaps |
| Battery | Tile downloads + decode; pause when leaving Navigation tab |
| Smooth nav camera | Possible with throttled `moveAndRotate` (already in code) |
| Vector / rich style | Weak without extra plugins |
| Dependencies | Already present; Impeller disabled for PowerVR |

**Fit:** Best default for a low-RAM phone and minimal APK/native surface area.

### B) MapLibre GL (`maplibre_gl`) + native vector

| Aspect | Assessment for A02 |
|---|---|
| Rendering | Native C++ / GPU via Platform View |
| RAM | Higher native heap + GL context; risk under memory pressure |
| Battery | GPU continuous render unless paused |
| Smoothness | Often smoother for camera/vector roads **on mid/high devices**; Samsung + Flutter ≥3.29 has reported jank issues |
| Setup cost | Current `maplibre_gl` 0.27 docs want **JDK 21**; this machine has **JDK 17 only** |
| A02 GPU | MediaTek MT6739 / PowerVR GE8100 is weak for sustained GL |

**Fit:** Attractive for “smooth animated 2D,” but **heavier** and **unproven** on A02. Do not adopt before a measured A/B.

### Recommendation (pending benchmark)

1. Keep **`flutter_map` + TomTom raster** as the production path for Milestone-1 style prototype.  
2. Only switch to MapLibre if an A02 release benchmark shows clearly better frame time / lower jank **without** worse PSS RAM.  
3. Never pre-warm MapLibre from Dashboard (spec: no map init outside Navigation).

---

## 3. TomTom Routing / Morocco traffic

### What Routing API provides (official Calculate Route docs)

- `traffic=true` → uses available live traffic in ETA  
- `routeType=fastest`, `travelMode=car`  
- `maxAlternatives` for alternate routes  
- `computeTravelTimeFor=all` → no-traffic vs live-traffic times when returned  
- Morocco appears on TomTom’s **consumer traffic coverage** lists (stronger than Magic Earth’s SA-only Africa list)

### What it does **not** provide by itself

- A complete navigation SDK (map-matching, guidance events, voice pipeline)  
- Proof that Casablanca congestion quality is good enough — **must be drive-tested**  
- Unlimited 0 MAD use if free quotas are exceeded (Pay-as-you-grow exists)

**OSRM / Valhalla:** explicitly rejected for live traffic (spec + this review).

---

## 4. Licensing & “zero ongoing cost” (critical)

Sources reviewed:

- [TomTom Developer Terms](https://developer.tomtom.com/terms-and-conditions)  
- [Pricing](https://docs.tomtom.com/pricing/)  
- Copyright / third-party product terms (attribution)

### Free quotas (marketing / pricing page)

- Free monthly requests per API, no card required to start  
- Examples: ~**200K** map tiles/month, ~**20K** Routing/month (confirm on your account dashboard)  
- Unused free limits **do not roll over** (terms §8.5)

### Hard legal definitions (terms)

- **Evaluation Use** = internal evaluation/testing only (royalty-free under §2.2).  
- **Navigation Functionality** = *“real-time provision of directions (visual or verbal) that guide a user through each turn… based on the user's current location… [and] change the route in real time…”*  
- §2.1 Maps API license for a Subscription Plan **excludes Automotive Usage and Navigation Functionality** unless TomTom grants them in a **separate written agreement**.  
- **Attribution** required (© TomTom; Copyrights API / logo rules). Caching tightly limited.  
- **Permitted Solution** wording centers on apps with **Asset Management Functionality** (tracking/routing of mobile assets) — personal single-driver companion is not clearly the same product class; confirm with TomTom.

### Implication for My Logan priorities

| Priority | Status |
|---|---|
| Traffic-aware route + ETA display | Plausible under Maps Routing API + free tier **for evaluation / non-TBT use** |
| Automatic rerouting + Darija turn-by-turn while driving | Matches **Navigation Functionality** definition → **needs written TomTom clearance**; may require Navigation SDK / paid plan |
| Zero MAD/month forever | **Not guaranteed** once free quotas are exceeded or if Navigation SDK license is required |

**Stop condition:** Do not deepen turn-by-turn / Darija-on-maneuver integration until TomTom answers in writing:

1. Is personal one-phone Android turn-by-turn allowed under free Maps APIs?  
2. Or is a Navigation SDK / separate agreement required (and at what cost)?  
3. Is Morocco live traffic included for Casablanca Routing ETA on free tier?

---

## 5. Map-rendering benchmark plan

Scripted A/B (same Casablanca camera path, ~45s pan/rotate/zoom):

| Metric | How |
|---|---|
| Frame build times | Flutter timeline / simple frame counter |
| Approx. RAM | `adb shell dumpsys meminfo com.meinloga.my_logan` |
| Subjective jank | Owner note during run |

### Measured on SM-A022F (2026-11-03)

Release harness: `lib/benchmark/map_engine_bench.dart` with `--dart-define=AUTO_BENCH=true`  
Stress: Casablanca pan/zoom/rotate ~45s, OSM raster tiles (**engine cost only**, not TomTom traffic).

| Engine | Result |
|---|---|
| **flutter_map** | `frames=2626` · `slow(>22ms)=20` · **avg 17.16 ms** (~58 FPS mean) · **max 401.77 ms** (spikes) · 44s |
| **flutter_map RAM (mid)** | Java heap ~1.5 MB · Native ~15 MB · **Graphics ~41 MB** |
| **MapLibre GL** | **Not run** — `maplibre_gl` 0.27 wants **JDK 21**; this PC has JDK 17 only |

Interpretation: `flutter_map` is usable on A02 for restrained 2D nav, but **max frame ~400 ms** means occasional stutters under aggressive camera motion — keep camera updates throttled (already in nav session). MapLibre remains a candidate only after JDK 21 + a second A/B; do not switch blindly for “smoother” marketing.

```powershell
flutter run -t lib/benchmark/map_engine_bench.dart --release -d R58R37ESBEJ --dart-define=AUTO_BENCH=true
adb shell dumpsys meminfo com.meinloga.my_logan
```

---

## 6. What not to do next

- Do not rewrite Fuel / Garage / Reminders / Dashboard.  
- Do not add MapLibre as default engine without A02 numbers.  
- Do not claim Darija navigation complete.  
- Do not enable TomTom Pay-as-you-grow without owner OK.  
- Do not substitute OSRM/Valhalla for traffic.

## 7. Owner actions

1. Plug in Galaxy A02 (USB debugging).  
2. Install JDK 21 if you want MapLibre included in the A/B.  
3. Create TomTom key (evaluation) and ask TomTom the three licensing questions above.  
4. Approve either: (a) stay on route-preview only until written nav clearance, or (b) pursue Navigation SDK path knowing cost may leave 0 MAD.
