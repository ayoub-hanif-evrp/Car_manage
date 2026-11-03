# TomTom navigation — feasibility (owner decision)

**Date:** 2026-11-03  
**Decision:** Replace Magic Lane with **TomTom Maps APIs** for the navigation prototype.  
**Sources:** [docs.tomtom.com/pricing](https://docs.tomtom.com/pricing/), [Calculate Route](https://developer.tomtom.com/routing-api/documentation/tomtom-maps/calculate-route), TomTom Traffic coverage support article (lists **Morocco**).

## Products used in this prototype

| Need | API | Notes |
|---|---|---|
| 2D map tiles | Map Display **Raster Tiles** (`map/1/tile/...`) | Compatible with `flutter_map` TileLayer |
| Destination search (Morocco) | Search **Fuzzy Search** (`search/2/...`, `countrySet=MA`) | Free tier listed under Places / Search |
| Traffic-aware route + ETA + alternatives | Routing **Calculate Route** (`routing/1/calculateRoute/...`) | `traffic=true`, `routeType=fastest`, `travelMode=car`, `maxAlternatives` |
| Live GPS | Device `geolocator` | Not a TomTom API |

This is a **Routing + Maps REST** integration, **not** TomTom’s native Navigation SDK. Turn-by-turn maneuver events / Darija wiring come in a later milestone.

## Free quotas (official pricing page, monthly, no credit card to start)

Observed free allowances relevant to this app:

- Map Display raster/vector tiles: **200K**/month  
- Routing API: **20K**/month  
- Search (legacy Fuzzy): **2.5K**/month (Orbis Places Suggest/Discover have higher free caps if migrated later)  
- Traffic flow/incident **tiles**: **200K**/month (optional overlay; not required for traffic-aware ETA — routing uses `traffic=true`)

**Cost policy for My Logan:** stay inside free quotas. Do **not** enable Pay-as-you-grow / prepaid overage without explicit owner permission. If a request fails with quota/auth errors, surface them honestly.

## Morocco live traffic

- TomTom’s **consumer** traffic-coverage list includes **Morocco**.  
- Developer Routing docs state routes use **current traffic** when `traffic=true`.  
- This is stronger evidence than Magic Earth’s Africa list (South Africa only), but **Casablanca drive quality must still be verified on the Galaxy A02** — do not treat docs alone as proof of local ETA accuracy.

## Licensing / personal use

- Public developer portal: free monthly requests to start; usage-based growth beyond free.  
- Attribution required for map display (show “© TomTom”).  
- API key must never be committed; inject with `--dart-define=TOMTOM_API_KEY=...`.  
- Native SDK license text is separate; this app uses **HTTPS REST APIs**, not the proprietary Maps SDK binary.

## Galaxy A02 approach

- Raster 2D tiles only (no 3D buildings).  
- GPS `distanceFilter` ≥ 8 m; camera updates throttled.  
- Route refresh / off-route recalculation throttled (not every GPS sample).  
- Navigation resources start only on the Navigation tab.

## Owner action required

Provide a TomTom developer API key for a **release** build:

```powershell
flutter build apk --release --dart-define=TOMTOM_API_KEY=YOUR_KEY
adb install -r build\app\outputs\flutter-apk\app-release.apk
```
