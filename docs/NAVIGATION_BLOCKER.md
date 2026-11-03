# Navigation — OpenFreeMap + OSRM prototype

**Date:** 2026-11-03  
**Device:** Samsung Galaxy A02 (SM-A022F), Android 10

## Decision

Switched away from TomTom / Magic Lane / Mapbox / Google for this prototype.

**Stack (no accounts, no API keys):**

| Piece | Role |
|---|---|
| MapLibre GL Flutter | Native 2D vector map |
| OpenFreeMap Liberty | Free map style/tiles |
| Public FOSSGIS OSRM (`router.project-osrm.org`) | Driving routes, distance, ETA estimate, maneuvers |
| Geolocator | Live GPS |
| Local Darija MP3s | Planned — not wired yet |

## Honest limitations

- **No live congestion / traffic delays** in Casablanca. ETA is a **road-network estimate**.
- Public OSRM: ≤1 request/second, identifying User-Agent, **no uptime SLA**.
- Not Waze-level reliability.

## Architecture notes

- Map initializes only on the Navigation tab.
- Route refresh is rate-limited; never on every GPS sample.
- Car records remain SQLite-only and independent of the map.

See also [NAV_ARCHITECTURE_REVIEW.md](NAV_ARCHITECTURE_REVIEW.md) (prior TomTom licensing findings still useful historically).
