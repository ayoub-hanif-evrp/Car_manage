# Navigation — OpenFreeMap + OSRM + Nominatim

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
| Public Nominatim | Destination search by name (Morocco) |
| Geolocator | Live GPS |
| Local Darija MP3s | Planned — not wired yet |

## Honest limitations

- **No live congestion / traffic delays** in Casablanca. ETA is a **road-network estimate**.
- Public OSRM: ≤1 request/second, identifying User-Agent, **no uptime SLA**.
- Not Waze-level reliability.

## Nominatim search policy

Destination search uses **public Nominatim** with these hard rules:

- **Submit-on-search only** — no autocomplete / typeahead (OSMF policy forbids bulk autocomplete).
- ≤1 request/second, identifying `User-Agent` (`MyLogan/0.1 …`).
- `countrycodes=ma` bias; in-memory cache for identical queries.
- Do not add Photon/Pelias autocomplete against public Nominatim.

Policy: https://operations.osmfoundation.org/policies/nominatim/

## Architecture notes

- Map initializes only on the Navigation tab.
- Plan mode: bottom sheet with Search + Home/Work/Saved + Recent + route ETA cards.
- Drive mode: next-maneuver HUD, remaining distance/time, non-live ETA chip.
- Main + alternative OSRM polylines; selected route highlighted.
- Car marker: MapLibre symbol (`assets/nav/car_marker.png`) rotated by GPS/route heading.
- Route refresh is rate-limited; never on every GPS sample.
- Car records remain SQLite-only and independent of the map.

See also [NAV_ARCHITECTURE_REVIEW.md](NAV_ARCHITECTURE_REVIEW.md) (prior TomTom licensing findings still useful historically).
