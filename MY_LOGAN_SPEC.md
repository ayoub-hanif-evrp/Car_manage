# My Logan — Product and Implementation Specification

**Status:** Version 1.0 — agreed scope for a personal app  
**Owner:** One driver, using a **2013 Dacia Logan** in Morocco  
**Target:** Android on a **Samsung Galaxy A02** (low-end device; RAM and Android version must be confirmed on the physical phone)  
**Development:** Flutter with Cursor AI; Git version control  
**Priority order:** (1) dependable navigation, (2) fast and smooth performance, (3) zero or very low ongoing cost, (4) simple car records, (5) polished but restrained visuals.

> **Instructions to Cursor:** Treat this file as the single source of truth for the application. Read it fully before planning or coding. Implement **one milestone at a time**; do not create the entire app in a single pass. At the end of each milestone, run relevant checks, summarize what genuinely works, list outstanding limitations, and **stop for review**. Ask before adding any feature or dependency not specified here. Never claim that simulated routing, traffic, voice, or GPS is real functionality.

## 1. Product concept and scope

Build **My Logan**, a **personal-use, Android-only** car companion. It manages fuel, repairs, simple reminders, and expenses, and includes **online navigation with live traffic-aware routes, ETA, rerouting and spoken Moroccan Darija directions** if the chosen legal/technical provider actually supports the required data and events.

- **No commercial product**, user registration, subscriptions, fleet management, EVRP features, social network, parking records, general expense categories, OBD-II integration, or chatbot.
- No backend/database service unless genuinely unavoidable for a navigation-provider integration; **local SQLite** for all car records.
- Currency is **Moroccan dirham (MAD / DH)**; distances in km; fuel in liters (L); fuel efficiency in L/100 km.
- The car is old: do **not** assume a digital fuel-consumption display or access to the car ECU.
- Keep the interface minimal: **Dashboard, Fuel, Garage, Navigation**. Reminders should be a simple card/list accessible from Dashboard, not a complex fifth module.
- No parking-position history or parking/toll/washing/insurance-payment tracking.

## 2. Dashboard — exact features

- This month's **total spending = fuel purchases + repair entries** for that calendar month. No other categories.
- This month's **fuel spending**, **repair spending**, and **number of fuelings**.
- Lightweight chart of **monthly total spending** with a fuel/repairs breakdown (e.g., last 6 months); option to view a previous month.
- Total recorded spending over all time; recent transactions (fuel or repair).
- Latest **manually recorded odometer** reading, clearly labeled (not a live reading).
- Show calculated average fuel consumption (L/100 km) and fuel cost/km **only if reliable full-tank records permit it**; otherwise show `Not enough data` and explain the full-tank requirement.
- Upcoming reminders: oil change, insurance, vignette, visite technique.
- Display all totals in DH, no financial projections or fabricated savings.

## 3. Fuel tracking — exact data and calculations

### Fuel-entry form
Required:
- Refueling **date** (default today).
- **Liters purchased**, positive number.
- **Total paid in DH**, nonnegative number.
- **Odometer reading** in km, greater than or equal to previous accepted reading (normally required for consumption tracking).

Optional:
- Fuel station free text (e.g. Afriquia, Shell, TotalEnergies).
- **Full tank / Plein** checkbox; default true only if the owner confirms this habit.

Automatically calculate **DH per liter = amount paid / liters**.

### History and reports
- List fuelings newest first with date, odometer, liters, DH, DH/L, station if present.
- Edit and delete entries with confirmation; totals and consumption recalculate immediately.
- Monthly fuel expenditure is **the sum of amounts paid for purchases dated in that month** (regardless of whether the fuel was consumed in the same month).
- Monthly liters purchased is the **sum of recorded liters purchased that month**; don't mislabel these as liters consumed.

### Accurate fuel consumption without a digital dashboard
Use the **full-to-full method**. A full tank alone does not measure consumption; **two successive recorded full tanks** establish an interval. For each valid interval:

- **Distance driven = second full-tank odometer − first full-tank odometer**.
- **Fuel consumed ≈ total liters purchased after the first full tank through and including the second full tank**. This allows partial fillings in between, provided *all* intermediate purchases were recorded.
- **L/100 km = 100 × interval liters / distance driven**.
- **Fuel cost/km = sum of prices paid for those same interval purchases / interval distance**.
- The *first full tank's liters and cost do not belong to the first measured interval*. Never double count a purchase when computing aggregate averages.
- For longer-term average, use **total measured liters / total measured distance × 100**, and **total measured interval fuel expense / total measured distance**, using only non-overlapping valid intervals.
- If odometer is missing, readings are invalid, a fill was skipped, or there are not two valid full-tank endpoints, show `Insufficient reliable data`; still display price, liters purchased, and spending.
- This yields an **estimate**, since differences in pump shutoff and tank level affect precision.
- Do not use continuous GPS tracking for fuel accounting. User never needs to press “start driving” for this feature.

### Calculation test cases
- Full tank at 150,000 km, full tank at 150,500 km with 35 L costing 420 DH, no intermediate fuel: **500 km**, **7.0 L/100 km**, **0.84 DH/km**.
- If 10 L are purchased between two full-tank endpoints and the second fill adds 25 L, consumption uses **35 L**, not just 25 L.
- Three fuel purchases for 200, 300, and 250 DH within a month: **750 DH** monthly fuel spending.

## 4. Garage & repairs — deliberately simple

Each repair has **only**:
- Date (default today).
- **Cause / short description** (free text, e.g. `Plaquettes de frein`, `Problème démarreur`).
- **Total price in DH**.

Features: add, edit, delete, and chronological repair history; monthly and lifetime repair totals. No mechanic database, parts breakdown, receipt scans, warranties, labor fields, or repair categories.

## 5. Reminders — only four kinds

1. **Oil change (vidange):** user enters date and/or odometer of last oil change and defines the next date and/or odometer target or an interval. Show reminders when date is due; mileage-based reminder only updates when a new odometer reading is recorded. Do not pretend the app reads the vehicle's odometer automatically.
2. **Insurance expiry:** user enters expiration date; local notification at a configurable lead time.
3. **Vignette:** user enters reminder/due date; local notification. Do not assume a fixed date without user configuration.
4. **Visite technique:** user enters next deadline; local notification.

Show upcoming/due/overdue states. Allow changing dates and marking a reminder renewed/completed. Keep notifications local, minimal, and only for these four categories. Ask Android notification permission when needed.

## 6. Navigation — quality is essential, but must be validated

### Desired user-facing features
- **Online 2D map** with reliable GPS positioning, clear streets and destination search within Morocco.
- Choose a destination, preview a **fastest traffic-aware driving route** if provider supplies traffic data for the area, and show route geometry.
- Show **remaining road distance**, **remaining travel time**, and **estimated arrival clock time**.
- Present **alternative routes** when provided; make their ETA comparison clear.
- **Turn-by-turn maneuver instruction** with large turn icon and next-turn distance.
- **Automatic off-route rerouting** and timely ETA refresh, using provider navigation functionality if supported.
- **Smooth car marker and camera following** with restrained animation; prioritize correct map matching and accurate guidance over visual effects.
- Display available congestion visualization only where supported by the provider, and label data limitations honestly.
- Save a short list of favorite destinations (e.g., Home, University). **No saved parking position**.
- Should handle poor connectivity gracefully: show last known route when permitted, indicate loss of live updates, never show stale ETA as live.
- The phone must not execute traffic prediction locally: use a verified traffic provider. **OSRM/public OSM alone are not real-time traffic solutions.**

### Provider selection: mandatory feasibility gate
1. **Investigate the current official Magic Lane Flutter SDK first** (`magiclane_maps_flutter`), including Android/Flutter requirements, traffic/rerouting APIs, route progress callbacks, and location/voice events. Read the up-to-date official docs; no guessed API calls.
2. **Confirm licensing in writing/documentation:** is indefinite use of this SDK for a **single personal Android car app** permitted, and is it free beyond a trial? Identify terms for driving navigation specifically.
3. **Confirm traffic-aware routing and ETA coverage for Casablanca/Morocco** and what actually refreshes during a drive. General worldwide map coverage is not proof of reliable local live traffic.
4. If Magic Lane fails a critical requirement, **compare alternatives** (e.g. Mapbox traffic-aware routing with an appropriate permitted vehicle-navigation license); do not assume general API free quotas imply vehicle navigation is licensed for free.
5. If no SDK meets the **free + compatible + real-traffic** requirements, **stop and report the trade-offs** to the owner before implementing a fake or illegally licensed replacement.
6. Public community OpenStreetMap tiles are not an unrestricted free production tile CDN. Respect attribution, identification, and usage rules if used for experiments.

### Darija audio guidance
- **Use short prerecorded audio clips**, not a continuously running speech model on the Galaxy A02.
- Trigger clips from **actual navigation maneuver events**, never fake fixed-distance messages.
- Support essential patterns: `continue straight`, `turn left/right`, `in [distance] meters`, `roundabout exit [number]`, `recalculate`, `arrived`.
- Example prompts (wording can be refined by the owner):
  - `بقا نيشان`
  - `من بعد ميتين متر، دور على ليمن`
  - `دور على ليسر`
  - `فالرومبوان، خود الخرجة الثانية`
  - `عاودنا حسبنا الطريق`
  - `وصلتي للوجهة ديالك`
- Store audio assets locally and play them with a lightweight audio player; avoid overlapping announcements. Give the user on/off volume controls on the navigation screen.
- **French guidance fallback** for unsupported maneuvers if the SDK permits it. Arbitrary street-name reading in Darija is **out of scope**.
- Until real clips are supplied, implement clearly named placeholder asset paths / a record-your-clips checklist, not copyrighted or fabricated audio. Never claim Darija voice is complete before actual device playback tests.

## 7. Galaxy A02 performance and UX requirements

- **Release APK**, not Flutter debug mode, is the basis for real performance judgment. Profile mode can help locate bottlenecks.
- **Navigation initializes only when opening Navigation or starting a trip**, and its listeners/resources are disposed when leaving navigation. No background GPS when not actively navigating.
- Use **simple 2D vector/native map**, no 3D buildings, terrain, satellite mode, unnecessary shadows/animations or heavy background AI.
- Car records/dashboard should open rapidly and remain usable **offline**; never initialize the map from the dashboard.
- Minimize dependency count, full-screen rebuilds and repeated route/API requests. Use local UI state updates for progress and refresh traffic based on provider recommendations rather than calling routing APIs on every GPS sample.
- Ensure camera motion is smooth **without** restarting expensive animations for each GPS reading; prefer the SDK's tested camera/map-matching system.
- Respect low-memory lifecycle: app background/foreground, phone call, screen off, permission denial, missing GPS, no data connection and Android battery optimizations.
- Native navigation/foreground service only when required, legal and carefully configured. No broad always-on background tracking.
- Measure **real** frame jank, memory, startup time, battery/heat over a 20–30 minute test, not merely successful compilation. Keep logs of errors and navigation events.
- Do not promise Waze-equivalent accuracy or specific FPS before measuring on the actual phone.

## 8. Technical architecture — minimum practical complexity

- Flutter Android application with a clean feature-based directory layout.
- Lightweight state management: use Flutter primitives or one focused state-management package if justified. Avoid overengineering.
- **SQLite** (Drift or another well-maintained SQLite integration) for fuel, repair, reminder, and saved-place records.
- Wrap the navigation SDK behind a **NavigationService** abstraction so a bad provider can be replaced without rewriting the app.
- A small calculation layer with pure, unit-tested functions for fuel metrics and monthly totals.
- Local Android notifications for reminders.
- No authentication, Firebase, push notifications, cloud database, VPS, analytics SDK or in-app ads.
- API keys/tokens: follow provider-recommended Android/app restrictions and avoid committing secrets or using unrestricted service credentials in source control.
- UI: clear typography, large driving instructions, high contrast, small number of screens, minimal design effects; navigation controls usable in a mounted phone without extended interaction while driving.

## 9. Implementation milestones and mandatory stop gates

### Milestone 0 — feasibility and environment (DO THIS FIRST)
- Inspect Flutter, Android SDK, connected A02's Android version/RAM if available, and relevant SDK constraints.
- Research and document navigation SDK licensing, traffic coverage, ongoing cost, and compatibility.
- Create only minimal project skeleton + a short feasibility report.
- **Stop for owner review** if any essential compatibility, coverage, or cost constraint is unresolved.

### Milestone 1 — smallest real navigation prototype
- Actual map + GPS + destination search + real online traffic-aware route + ETA (not a hardcoded line).
- Simple 2D route display and minimal camera-following behavior.
- Compile release APK and test on Galaxy A02. Collect performance metrics and traffic/ETA observations.
- Stop; report whether the route and ETA actually work in Casablanca and whether the animation is acceptable.

### Milestone 2 — usable navigation
- Turn-by-turn maneuvers, road distance, off-route rerouting, progress, ETA refresh, alternatives as supported.
- Darija clip-triggering mechanism with verified events, real clips when provided, French fallback where permitted.
- Release-build driving test; fix meaningful stutters, wrong turns, routing failures, background lifecycle problems.
- Stop; do not proceed if real navigation is unsafe or unreliable.

### Milestone 3 — car records and reminders
- Local database and forms for fuel, garage, four reminder kinds.
- Unit tests for full-to-full consumption, cost/km, monthly totals, editing/deleting and invalid entries.
- Local notifications, with proper Android permissions; no unrelated data pages.

### Milestone 4 — dashboard and finish
- Dashboard cards, lightweight monthly charts, navigation entry point, polish and empty states.
- Test on the A02, including app startup, switching between car screens and navigation, long drives, and data persistence.
- Provide final release APK instructions, tested feature checklist, remaining limitations and actual costs.

## 10. Cursor workflow and definition of done

For **every milestone**:
1. Read this spec and existing repository state.
2. State what is being implemented, dependencies and any risks **before editing**.
3. Implement only that milestone. Avoid gratuitous refactors and unrelated features.
4. Run `flutter analyze`, applicable `flutter test`, and a build where possible. Do not claim to have run a test you couldn't execute.
5. Summarize changed files, tests/results, known limitations, SDK/API usage and estimated ongoing cost.
6. Commit to Git (or provide a clean diff for review). **Stop and ask for the next milestone**.

**Definition of done:** The owner can genuinely use the feature on a real Galaxy A02; no demo data passed off as live; reliable navigation behavior is tested in Morocco; fuel math is correct; unused functionality does not degrade phone performance.

## 11. Explicit non-goals

Do **not** add parking history/expenses, tolls, washing, mechanic contacts, invoice photos, complex repair details, cloud sync, user accounts, AI assistant, EVRP, OBD, vehicle diagnostics, social alerts, police/hazard crowdsourcing, Android Auto, CarPlay, or any feature not expressly described above.

## 12. Documentation to verify during development

- Magic Lane Flutter SDK: https://developer.magiclane.com/docs/flutter/guides/introduction/
- Magic Lane Flutter minimum requirements: https://developer.magiclane.com/docs/flutter/guides/introduction/minimum-requirements/
- Magic Lane better route detection: https://developer.magiclane.com/docs/flutter/guides/navigation/better-route-detection/
- Cursor project context rules: https://docs.cursor.com/context/rules-for-ai

**These links are references, not proof of license, permanent free usage, real-time traffic quality in Casablanca, or Galaxy A02 smoothness. Verify the current terms and behavior before proceeding.**
