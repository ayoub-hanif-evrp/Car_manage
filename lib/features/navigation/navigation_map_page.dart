import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/app_state.dart';
import '../../core/format.dart';
import '../favorites/favorites_panel.dart';
import 'navigation_session.dart';
import 'tomtom_config.dart';
import 'tomtom_models.dart';

class NavigationMapPage extends StatefulWidget {
  const NavigationMapPage({super.key, required this.appState});

  final AppState appState;

  @override
  State<NavigationMapPage> createState() => _NavigationMapPageState();
}

class _NavigationMapPageState extends State<NavigationMapPage> {
  late final NavigationSession _session;
  final MapController _map = MapController();
  final TextEditingController _search = TextEditingController();
  LatLng? _lastCameraTarget;

  static const _casablanca = LatLng(33.5731, -7.5898);

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
    _search.dispose();
    _map.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    setState(() {});
    _maybeFollowCamera();
  }

  void _maybeFollowCamera() {
    if (!_session.followCamera) return;
    final pos = _session.userPosition;
    if (pos == null) return;
    if (_lastCameraTarget != null) {
      final moved = const Distance()(pos, _lastCameraTarget!);
      if (moved < 4) return;
    }
    _lastCameraTarget = pos;
    final heading = _session.userHeading ?? 0;
    try {
      _map.moveAndRotate(pos, math.max(_map.camera.zoom, 16), -heading);
    } catch (_) {
      // Map not ready yet.
    }
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
    final pos = _session.userPosition ?? _casablanca;
    final route = _session.activeRoute;
    final routes = _session.routeResponse?.routes ?? const <TomTomRouteOption>[];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search Morocco (TomTom)',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _search.clear();
                                  _session.scheduleSearch('');
                                  setState(() {});
                                },
                              ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) {
                        setState(() {});
                        _session.scheduleSearch(v);
                      },
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
              if (_session.searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Material(
                    elevation: 1,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _session.searchResults.length,
                      itemBuilder: (context, i) {
                        final r = _session.searchResults[i];
                        return ListTile(
                          dense: true,
                          title: Text(r.title),
                          subtitle: Text(r.subtitle, maxLines: 1),
                          onTap: () => _session.selectDestination(r),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_session.destination != null || route != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _HudCard(
              destination: _session.destination?.title,
              remaining: _session.remainingMeters,
              remainingSeconds: _session.remainingSeconds,
              eta: _session.etaClock,
              trafficDelay: route?.trafficDelayInSeconds,
              liveTrafficTime: route?.liveTrafficTravelTimeInSeconds,
              noTrafficTime: route?.noTrafficTravelTimeInSeconds,
              routingBusy: _session.routingBusy,
              fmtDistance: _fmtDistance,
              fmtDuration: _fmtDuration,
              onClear: _session.clearRoute,
              onRefresh: _session.refreshRoute,
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
                final selected = i == _session.selectedRouteIndex;
                return ChoiceChip(
                  label: Text(
                    '${i == 0 ? 'Fastest' : 'Alt $i'} · ${_fmtDuration(r.travelTimeInSeconds)} · ${_fmtDistance(r.lengthInMeters)}',
                  ),
                  selected: selected,
                  onSelected: (_) => _session.selectRouteIndex(i),
                );
              },
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
                      onPressed: () => _session.selectFavorite(
                        LatLng(f.latitude, f.longitude),
                        f.name,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: pos,
                  initialZoom: 14,
                  minZoom: 5,
                  maxZoom: 18,
                  backgroundColor: const Color(0xFFE8EEE9),
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture && _session.followCamera) {
                      _session.setFollowCamera(false);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: TomTomConfig.rasterTileUrlTemplate(
                      TomTomConfig.apiKey,
                    ),
                    userAgentPackageName: 'com.meinloga.my_logan',
                    maxZoom: 18,
                    keepBuffer: 2,
                    panBuffer: 1,
                  ),
                  if (routes.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        for (var i = 0; i < routes.length; i++)
                          if (i != _session.selectedRouteIndex)
                            Polyline(
                              points: routes[i].points,
                              strokeWidth: 4,
                              color: Colors.blueGrey.withValues(alpha: 0.45),
                            ),
                        if (route != null)
                          Polyline(
                            points: route.points,
                            strokeWidth: 5.5,
                            color: const Color(0xFF1B4D3E),
                          ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (_session.destination != null)
                        Marker(
                          point: _session.destination!.position,
                          width: 36,
                          height: 36,
                          child: const Icon(
                            Icons.place,
                            color: Color(0xFF8B5E3C),
                            size: 36,
                          ),
                        ),
                      if (_session.userPosition != null)
                        Marker(
                          point: _session.userPosition!,
                          width: 44,
                          height: 44,
                          child: Transform.rotate(
                            angle: ((_session.userHeading ?? 0) * math.pi / 180),
                            child: const Icon(
                              Icons.navigation,
                              color: Color(0xFF0B3D2E),
                              size: 36,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SimpleAttributionWidget(
                    source: Text('© TomTom'),
                    alignment: Alignment.bottomLeft,
                  ),
                ],
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Column(
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'follow',
                      onPressed: () {
                        _session.setFollowCamera(true);
                        _maybeFollowCamera();
                      },
                      child: Icon(
                        _session.followCamera
                            ? Icons.my_location
                            : Icons.location_searching,
                      ),
                    ),
                  ],
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
            child: Text(
              _session.statusNote!,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _HudCard extends StatelessWidget {
  const _HudCard({
    required this.destination,
    required this.remaining,
    required this.remainingSeconds,
    required this.eta,
    required this.trafficDelay,
    required this.liveTrafficTime,
    required this.noTrafficTime,
    required this.routingBusy,
    required this.fmtDistance,
    required this.fmtDuration,
    required this.onClear,
    required this.onRefresh,
  });

  final String? destination;
  final int? remaining;
  final int? remainingSeconds;
  final DateTime? eta;
  final int? trafficDelay;
  final int? liveTrafficTime;
  final int? noTrafficTime;
  final bool routingBusy;
  final String Function(int) fmtDistance;
  final String Function(int) fmtDuration;
  final VoidCallback onClear;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    destination ?? 'Route',
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh traffic route',
                  onPressed: routingBusy ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              [
                if (remaining != null) fmtDistance(remaining!),
                if (remainingSeconds != null) fmtDuration(remainingSeconds!),
                if (eta != null) 'ETA ${formatTime(eta!)}',
              ].join(' · '),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Traffic delay: ${trafficDelay ?? '—'}s'
              '${liveTrafficTime != null ? ' · live ${fmtDuration(liveTrafficTime!)}' : ''}'
              '${noTrafficTime != null ? ' · no-traffic ${fmtDuration(noTrafficTime!)}' : ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
