import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../favorites/favorites_panel.dart';
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
  MapLibreMapController? _map;
  Line? _routeLine;
  Circle? _carCircle;
  Circle? _destCircle;
  bool _styleReady = false;
  DateTime? _lastCameraAt;
  bool _userPanning = false;

  static const _casablanca = LatLng(33.5731, -7.5898);

  LatLng _ml(ll.LatLng p) => LatLng(p.latitude, p.longitude);

  @override
  void initState() {
    super.initState();
    _session = NavigationSession();
    _session.addListener(_onSession);
    _session.start();
  }

  @override
  void dispose() {
    _session.removeListener(_onSession);
    _session.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    _syncMapOverlays();
    if (!_userPanning) _maybeFollowCamera();
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    await _syncMapOverlays();
    _maybeFollowCamera(force: true);
  }

  Future<void> _syncMapOverlays() async {
    final map = _map;
    if (!_styleReady || map == null) return;

    try {
      final route = _session.activeRoute;
      if (_routeLine != null) {
        await map.removeLine(_routeLine!);
        _routeLine = null;
      }
      if (route != null && route.points.length >= 2) {
        _routeLine = await map.addLine(
          LineOptions(
            geometry: [for (final p in route.points) _ml(p)],
            lineColor: '#1B4D3E',
            lineWidth: 5.5,
            lineOpacity: 0.92,
          ),
        );
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
            circleRadius: 8,
            circleColor: '#8B5E3C',
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
      }

      final pos = _session.userPosition;
      if (_carCircle != null) {
        await map.removeCircle(_carCircle!);
        _carCircle = null;
      }
      if (pos != null) {
        _carCircle = await map.addCircle(
          CircleOptions(
            geometry: _ml(pos),
            circleRadius: 7,
            circleColor: '#0B3D2E',
            circleStrokeWidth: 2,
            circleStrokeColor: '#FFFFFF',
          ),
        );
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
    final bearing = _session.userHeading ?? 0;
    map.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _ml(pos),
          zoom: math.max(map.cameraPosition?.zoom ?? 16, 15.5),
          bearing: bearing,
          tilt: 0,
        ),
      ),
      duration: const Duration(milliseconds: 280),
    );
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
    final route = _session.activeRoute;
    final routes = _session.routeResponse?.routes ?? const <OsrmRouteOption>[];
    final center = _session.userPosition == null
        ? _casablanca
        : _ml(_session.userPosition!);
    final maneuver = _session.nextManeuver;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Tap map to set destination · OpenFreeMap + OSRM',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: 'Favorites',
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: FavoritesPanel(state: widget.appState),
                    ),
                  );
                },
                icon: const Icon(Icons.star_outline),
              ),
            ],
          ),
        ),
        if (widget.appState.favorites.isNotEmpty)
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in widget.appState.favorites)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(f.name),
                      onPressed: () => _session.selectFavorite(f),
                    ),
                  ),
              ],
            ),
          ),
        if (_session.destination != null || route != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.92),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _session.destinationLabel ?? 'Route',
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          onPressed: _session.routingBusy
                              ? null
                              : _session.refreshRoute,
                          icon: const Icon(Icons.refresh),
                        ),
                        IconButton(
                          onPressed: _session.clearRoute,
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
                      style: theme.textTheme.titleLarge,
                    ),
                    if (maneuver != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        maneuver.instruction,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Non-live ETA — OSRM has no real-time congestion data.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (routes.length > 1)
          SizedBox(
            height: 44,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              scrollDirection: Axis.horizontal,
              itemCount: routes.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final r = routes[i];
                return ChoiceChip(
                  label: Text(
                    '${i == 0 ? 'Main' : 'Alt $i'} · '
                    '${_fmtDuration(r.durationSeconds.round())} · '
                    '${_fmtDistance(r.distanceMeters.round())}',
                  ),
                  selected: i == _session.selectedRouteIndex,
                  onSelected: (_) => _session.selectRouteIndex(i),
                );
              },
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              MapLibreMap(
                styleString: OsrmConfig.openFreeMapLiberty,
                initialCameraPosition: CameraPosition(
                  target: center,
                  zoom: 14.5,
                ),
                minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
                compassEnabled: false,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: false,
                trackCameraPosition: true,
                myLocationEnabled: false,
                onMapCreated: (c) {
                  _map = c;
                  c.addListener(() {
                    // Detect user gesture via follow flag only.
                  });
                },
                onStyleLoadedCallback: _onStyleLoaded,
                onMapClick: (point, latLng) {
                  _session.selectMapDestination(
                    ll.LatLng(latLng.latitude, latLng.longitude),
                  );
                },
                onCameraIdle: () {},
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: 'follow',
                  onPressed: () {
                    _userPanning = false;
                    _session.setFollowCamera(true);
                    _maybeFollowCamera(force: true);
                  },
                  child: Icon(
                    _session.followCamera
                        ? Icons.my_location
                        : Icons.location_searching,
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
          ),
        ),
        if (_session.errorMessage != null)
          Material(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                _session.errorMessage!,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ),
        if (_session.statusNote != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(_session.statusNote!, style: theme.textTheme.bodySmall),
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            '© OpenFreeMap · © OpenStreetMap contributors · OSRM demo',
            style: TextStyle(fontSize: 11),
          ),
        ),
      ],
    );
  }
}
