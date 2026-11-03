import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import 'nominatim_client.dart';
import 'navigation_session.dart';
import 'osrm_config.dart';
import 'osrm_models.dart';

class NavigationMapPage extends StatefulWidget {
  const NavigationMapPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<NavigationMapPage> createState() => _NavigationMapPageState();
}

class _NavigationMapPageState extends State<NavigationMapPage> {
  late final NavigationSession _session;
  late final NominatimClient _search;
  MapLibreMapController? _map;
  final List<Line> _routeLines = [];
  Symbol? _carSymbol;
  Circle? _carCircle;
  Circle? _destCircle;
  bool _styleReady = false;
  bool _carImageReady = false;
  DateTime? _lastCameraAt;

  final _query = TextEditingController();
  List<NominatimPlace> _results = const [];
  bool _searching = false;
  String? _searchError;
  bool _sheetExpanded = true;
  bool _driveMode = false;

  static const _casablanca = LatLng(33.5731, -7.5898);

  LatLng _ml(ll.LatLng p) => LatLng(p.latitude, p.longitude);

  bool get _driving =>
      _driveMode &&
      _session.phase == NavPhase.navigating &&
      _session.activeRoute != null;

  @override
  void initState() {
    super.initState();
    _session = NavigationSession();
    _search = NominatimClient();
    _session.addListener(_onSession);
    _session.start();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    _search.dispose();
    _query.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    _syncMapOverlays();
    if (_session.followCamera) _maybeFollowCamera();
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    await _ensureCarImage();
    await _syncMapOverlays();
    _maybeFollowCamera(force: true);
  }

  Future<void> _ensureCarImage() async {
    final map = _map;
    if (map == null || _carImageReady) return;
    try {
      final data = await rootBundle.load('assets/nav/car_marker.png');
      final bytes = data.buffer.asUint8List();
      await map.addImage('my_logan_car', bytes);
      _carImageReady = true;
    } catch (e) {
      debugPrint('Car marker image failed: $e');
    }
  }

  Future<void> _syncMapOverlays() async {
    final map = _map;
    if (!_styleReady || map == null) return;

    try {
      for (final line in _routeLines) {
        await map.removeLine(line);
      }
      _routeLines.clear();

      final routes = _session.routeResponse?.routes ?? const <OsrmRouteOption>[];
      for (var i = 0; i < routes.length; i++) {
        if (i == _session.selectedRouteIndex) continue;
        final r = routes[i];
        if (r.points.length < 2) continue;
        final line = await map.addLine(
          LineOptions(
            geometry: [for (final p in r.points) _ml(p)],
            lineColor: '#7A8794',
            lineWidth: 4,
            lineOpacity: 0.55,
          ),
        );
        _routeLines.add(line);
      }
      final active = _session.activeRoute;
      if (active != null && active.points.length >= 2) {
        final line = await map.addLine(
          LineOptions(
            geometry: [for (final p in active.points) _ml(p)],
            lineColor: '#0E6B5C',
            lineWidth: 6,
            lineOpacity: 0.95,
          ),
        );
        _routeLines.add(line);
      }

      final dest = _session.destination;
      if (_destCircle != null) {
        await map.removeCircle(_destCircle!);
        _destCircle = null;
      }
      if (dest != null) {
        _destCircle = await map.addCircle(
          CircleOptions(
            geometry: _ml(dest),
            circleRadius: 9,
            circleColor: '#B45309',
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }

      final pos = _session.userPosition;
      if (_carSymbol != null) {
        await map.removeSymbol(_carSymbol!);
        _carSymbol = null;
      }
      if (_carCircle != null) {
        await map.removeCircle(_carCircle!);
        _carCircle = null;
      }
      if (pos != null) {
        final heading = _session.userHeading ?? 0;
        if (_carImageReady) {
          _carSymbol = await map.addSymbol(
            SymbolOptions(
              geometry: _ml(pos),
              iconImage: 'my_logan_car',
              iconSize: 1.15,
              iconRotate: heading,
              iconAnchor: 'center',
            ),
          );
        } else {
          _carCircle = await map.addCircle(
            CircleOptions(
              geometry: _ml(pos),
              circleRadius: 7,
              circleColor: '#0E6B5C',
              circleStrokeWidth: 2,
              circleStrokeColor: '#FFFFFF',
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Map overlay sync: $e');
    }
  }

  void _maybeFollowCamera({bool force = false}) {
    if (!_session.followCamera && !force) return;
    final map = _map;
    final pos = _session.userPosition;
    if (map == null || pos == null) return;
    final now = DateTime.now();
    if (!force &&
        _lastCameraAt != null &&
        now.difference(_lastCameraAt!) < const Duration(milliseconds: 280)) {
      return;
    }
    _lastCameraAt = now;
    map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _ml(pos),
          zoom: math.max(map.cameraPosition?.zoom ?? 16, 15.5),
          bearing: _session.userHeading ?? 0,
          tilt: 0,
        ),
      ),
      duration: const Duration(milliseconds: 280),
    );
  }

  Future<void> _runSearch() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final results = await _search.search(_query.text);
      setState(() {
        _results = results;
        if (results.isEmpty) {
          _searchError = 'No places found in Morocco for that name.';
        }
      });
    } catch (e) {
      setState(() {
        _results = const [];
        _searchError = e.toString();
      });
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _goToNamed(String name, ll.LatLng target, {int? favoriteId}) async {
    final ok = await _session.selectNamedDestination(name: name, target: target);
    if (ok && mounted) {
      await widget.appState.recordDestinationUse(
        name: name,
        latitude: target.latitude,
        longitude: target.longitude,
        favoriteId: favoriteId,
      );
      setState(() {
        _driveMode = false;
        _sheetExpanded = true;
        _results = const [];
      });
    }
  }

  void _startDriving() {
    if (_session.activeRoute == null) return;
    setState(() {
      _driveMode = true;
      _sheetExpanded = false;
    });
    _session.setFollowCamera(true);
    _maybeFollowCamera(force: true);
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final h = m ~/ 60;
    final rem = m % 60;
    if (h > 0) return '${h}h ${rem.toString().padLeft(2, '0')}m';
    return '$m min';
  }

  String _fmtDistance(int meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 0 : 1)} km';
    }
    return '$meters m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final center = _session.userPosition == null
        ? _casablanca
        : _ml(_session.userPosition!);

    return Stack(
      children: [
        MapLibreMap(
          styleString: OsrmConfig.openFreeMapLiberty,
          initialCameraPosition: CameraPosition(target: center, zoom: 14.2),
          minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
          compassEnabled: false,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: false,
          trackCameraPosition: true,
          myLocationEnabled: false,
          onMapCreated: (c) => _map = c,
          onStyleLoadedCallback: _onStyleLoaded,
          onMapClick: (point, latLng) async {
            final ok = await _session.selectMapDestination(
              ll.LatLng(latLng.latitude, latLng.longitude),
            );
            if (ok && mounted) {
              await widget.appState.recordDestinationUse(
                name: 'Dropped pin',
                latitude: latLng.latitude,
                longitude: latLng.longitude,
              );
              setState(() {
                _driveMode = false;
                _sheetExpanded = true;
              });
            }
          },
        ),
        if (_driving) _buildDriveHud(theme) else _buildPlanSheet(theme),
        Positioned(
          right: 14,
          bottom: _driving ? 120 : (_sheetExpanded ? 320 : 120),
          child: FloatingActionButton.small(
            heroTag: 'follow',
            backgroundColor: LoganTheme.paper,
            foregroundColor: LoganTheme.ink,
            onPressed: () {
              _session.setFollowCamera(true);
              _maybeFollowCamera(force: true);
            },
            child: Icon(
              _session.followCamera ? Icons.my_location : Icons.location_searching,
            ),
          ),
        ),
        if (_session.phase == NavPhase.locating ||
            _session.phase == NavPhase.routing)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _buildDriveHud(ThemeData theme) {
    final maneuver = _session.nextManeuver;
    return Positioned(
      left: 12,
      right: 12,
      top: 12,
      child: Material(
        color: LoganTheme.paper.withValues(alpha: 0.96),
        elevation: 2,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _session.destinationLabel ?? 'Navigating',
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await _session.clearRoute();
                      setState(() {
                        _driveMode = false;
                        _sheetExpanded = true;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                [
                  if (_session.remainingMeters != null)
                    _fmtDistance(_session.remainingMeters!),
                  if (_session.remainingSeconds != null)
                    _fmtDuration(_session.remainingSeconds!),
                  if (_session.etaClock != null)
                    'ETA ${formatTime(_session.etaClock!)}',
                ].join(' · '),
                style: theme.textTheme.headlineSmall,
              ),
              if (maneuver != null) ...[
                const SizedBox(height: 6),
                Text(
                  maneuver.instruction,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: LoganTheme.muted,
                  ),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: LoganTheme.cautionSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Estimate only — no live traffic',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: LoganTheme.caution,
                  ),
                ),
              ),
              if (_session.routeResponse != null &&
                  _session.routeResponse!.routes.length > 1) ...[
                const SizedBox(height: 10),
                _RouteCards(
                  routes: _session.routeResponse!.routes,
                  selected: _session.selectedRouteIndex,
                  fmtDuration: _fmtDuration,
                  fmtDistance: _fmtDistance,
                  onSelect: _session.selectRouteIndex,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanSheet(ThemeData theme) {
    final home = widget.appState.favoriteByKind(PlaceKind.home);
    final work = widget.appState.favoriteByKind(PlaceKind.work);
    final saved = widget.appState.favorites
        .where((f) => f.kind == PlaceKind.saved)
        .take(4)
        .toList();
    final recents = widget.appState.recentDestinations;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: LoganTheme.paper,
        elevation: 8,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: SafeArea(
          top: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            constraints: BoxConstraints(
              maxHeight: _sheetExpanded
                  ? MediaQuery.sizeOf(context).height * 0.62
                  : 96,
            ),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD5DBE2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Where to?',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _sheetExpanded = !_sheetExpanded),
                      icon: Icon(
                        _sheetExpanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                      ),
                    ),
                  ],
                ),
                if (_sheetExpanded) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _query,
                          textInputAction: TextInputAction.search,
                          decoration: const InputDecoration(
                            hintText: 'Place or address in Morocco',
                            prefixIcon: Icon(Icons.search),
                          ),
                          onSubmitted: (_) => _runSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _searching ? null : _runSearch,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(88, 48),
                        ),
                        child: _searching
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Search'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Type a name, then press Search (no autocomplete — Nominatim policy).',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: LoganTheme.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _PlaceChip(
                          icon: Icons.home_outlined,
                          label: 'Home',
                          enabled: home != null,
                          onTap: home == null
                              ? null
                              : () => _goToNamed(
                                    home.name,
                                    ll.LatLng(home.latitude, home.longitude),
                                    favoriteId: home.id,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        _PlaceChip(
                          icon: Icons.work_outline,
                          label: 'Work',
                          enabled: work != null,
                          onTap: work == null
                              ? null
                              : () => _goToNamed(
                                    work.name,
                                    ll.LatLng(work.latitude, work.longitude),
                                    favoriteId: work.id,
                                  ),
                        ),
                        for (final f in saved) ...[
                          const SizedBox(width: 8),
                          _PlaceChip(
                            icon: Icons.star_outline,
                            label: f.name,
                            enabled: true,
                            onTap: () => _goToNamed(
                              f.name,
                              ll.LatLng(f.latitude, f.longitude),
                              favoriteId: f.id,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_session.routeResponse != null) ...[
                    const SizedBox(height: 12),
                    Text('Choose a route', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    _RouteCards(
                      routes: _session.routeResponse!.routes,
                      selected: _session.selectedRouteIndex,
                      fmtDuration: _fmtDuration,
                      fmtDistance: _fmtDistance,
                      onSelect: _session.selectRouteIndex,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Estimate only — no live traffic',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: LoganTheme.caution,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _startDriving,
                      icon: const Icon(Icons.navigation),
                      label: Text(
                        'Start to ${_session.destinationLabel ?? 'destination'}',
                      ),
                    ),
                  ],
                  if (_searchError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _searchError!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        if (_results.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Results', style: theme.textTheme.titleSmall),
                          for (final r in _results)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.place_outlined),
                              title: Text(r.name),
                              subtitle: Text(r.subtitle, maxLines: 2),
                              onTap: () => _goToNamed(
                                r.name,
                                ll.LatLng(r.latitude, r.longitude),
                              ),
                            ),
                        ],
                        if (recents.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Recent', style: theme.textTheme.titleSmall),
                          for (final r in recents)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history),
                              title: Text(r.name),
                              onTap: () async {
                                final ok = await _session.selectRecent(r);
                                if (ok && mounted) {
                                  await widget.appState.recordDestinationUse(
                                    name: r.name,
                                    latitude: r.latitude,
                                    longitude: r.longitude,
                                  );
                                  setState(() {
                                    _driveMode = false;
                                    _sheetExpanded = true;
                                  });
                                }
                              },
                            ),
                        ],
                        if (_session.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _session.errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          '© OpenFreeMap · © OpenStreetMap · OSRM demo',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: LoganTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceChip extends StatelessWidget {
  const _PlaceChip({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: enabled ? onTap : null,
      backgroundColor: enabled ? LoganTheme.accentSoft : LoganTheme.stone,
    );
  }
}

class _RouteCards extends StatelessWidget {
  const _RouteCards({
    required this.routes,
    required this.selected,
    required this.fmtDuration,
    required this.fmtDistance,
    required this.onSelect,
  });

  final List<OsrmRouteOption> routes;
  final int selected;
  final String Function(int) fmtDuration;
  final String Function(int) fmtDistance;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: routes.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = routes[i];
          final isSelected = i == selected;
          final eta = r.etaFrom(DateTime.now());
          return InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              width: 148,
              decoration: BoxDecoration(
                color: isSelected ? LoganTheme.accentSoft : LoganTheme.stone,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? LoganTheme.accent : const Color(0xFFD5DBE2),
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i == 0 ? 'Main route' : 'Alternative $i',
                    style: theme.textTheme.labelLarge,
                  ),
                  const Spacer(),
                  Text(
                    fmtDuration(r.durationSeconds.round()),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: LoganTheme.accent,
                    ),
                  ),
                  Text(
                    '${fmtDistance(r.distanceMeters.round())} · ETA ${formatTime(eta)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: LoganTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
