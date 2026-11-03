# Navigation — TomTom prototype

**Date:** 2026-11-03  
**Device:** Samsung Galaxy A02 (SM-A022F), Android 10 / API 29

## Decision

Magic Lane was stopped (cost + Morocco traffic uncertainty).  
**TomTom Maps APIs** are the selected provider for the navigation prototype.  
Details: [TOMTOM.md](TOMTOM.md).

## What ships in the prototype (with API key)

- Online TomTom raster 2D map (`flutter_map`)
- Live GPS positioning
- Morocco destination search
- Fastest traffic-aware route (`traffic=true`) + alternatives
- Remaining distance / time / ETA HUD from TomTom summary + GPS progress
- Camera follow + car marker rotation
- Favorites as destination shortcuts

## What is NOT claimed yet

- Full native TomTom Navigation SDK / polished turn-by-turn Darija events
- Galaxy A02 20–30 min performance proof
- Guaranteed Casablanca congestion quality (must be drive-tested)

## Owner action

Provide a free-tier TomTom API key and rebuild with  
`--dart-define=TOMTOM_API_KEY=...`  
Do not enable paid overage without approval.
