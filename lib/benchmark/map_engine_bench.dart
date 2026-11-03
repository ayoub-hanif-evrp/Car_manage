import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Isolated map-engine stress harness for Galaxy A02.
/// Run: flutter run -t lib/benchmark/map_engine_bench.dart --release
///
/// Does not touch car-record screens. MapLibre lane is documented-only until
/// JDK 21 is available and the owner clears TomTom Navigation Functionality licensing.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MapEngineBenchApp());
}

class MapEngineBenchApp extends StatelessWidget {
  const MapEngineBenchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Map engine bench',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B4D3E)),
        useMaterial3: true,
      ),
      home: const MapEngineBenchPage(),
    );
  }
}

enum BenchEngine { flutterMapRaster, mapLibrePlaceholder }

class MapEngineBenchPage extends StatefulWidget {
  const MapEngineBenchPage({super.key});

  @override
  State<MapEngineBenchPage> createState() => _MapEngineBenchPageState();
}

class _MapEngineBenchPageState extends State<MapEngineBenchPage>
    with SingleTickerProviderStateMixin {
  static const _casablanca = LatLng(33.5731, -7.5898);

  final MapController _map = MapController();
  BenchEngine _engine = BenchEngine.flutterMapRaster;

  bool _running = false;
  int _frames = 0;
  int _slowFrames = 0; // > 22 ms ~ <45 FPS
  double _maxFrameMs = 0;
  double _sumFrameMs = 0;
  DateTime? _startedAt;
  Duration _elapsed = Duration.zero;
  Timer? _cameraTimer;
  Ticker? _ticker;
  Duration? _lastTick;

  @override
  void initState() {
    super.initState();
    // Optional: flutter run -t lib/benchmark/map_engine_bench.dart --release --dart-define=AUTO_BENCH=1
    if (const bool.fromEnvironment('AUTO_BENCH')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_engine == BenchEngine.flutterMapRaster) _start();
      });
    }
  }

  @override
  void dispose() {
    _stop();
    _map.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!_running) return;
    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final dtMs = (elapsed - last).inMicroseconds / 1000.0;
    if (dtMs <= 0 || dtMs > 1000) return;
    _frames++;
    _sumFrameMs += dtMs;
    if (dtMs > _maxFrameMs) _maxFrameMs = dtMs;
    if (dtMs > 22) _slowFrames++;
    _elapsed = DateTime.now().difference(_startedAt!);
    if (_frames % 15 == 0 && mounted) setState(() {});
  }

  void _start() {
    _stop();
    setState(() {
      _running = true;
      _frames = 0;
      _slowFrames = 0;
      _maxFrameMs = 0;
      _sumFrameMs = 0;
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
      _lastTick = null;
    });

    _ticker = createTicker(_onTick)..start();

    var step = 0;
    _cameraTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_running || _engine != BenchEngine.flutterMapRaster) return;
      step++;
      final t = step / 40.0;
      final lat = _casablanca.latitude + 0.012 * math.sin(t);
      final lon = _casablanca.longitude + 0.012 * math.cos(t * 0.85);
      final zoom = 14.5 + 1.2 * math.sin(t * 0.5);
      final rotation = 25 * math.sin(t * 0.7);
      try {
        _map.moveAndRotate(LatLng(lat, lon), zoom, rotation);
      } catch (_) {}
      if (step >= 180) {
        // ~45s
        _stop();
        final avg = _avgFrameMs;
        // ignore: avoid_print — release bench must emit to logcat
        print(
          'BENCH_RESULT engine=flutter_map frames=$_frames '
          'slow=$_slowFrames avgMs=${avg?.toStringAsFixed(2)} '
          'maxMs=${_maxFrameMs.toStringAsFixed(2)} '
          'elapsedSec=${_elapsed.inSeconds}',
        );
        setState(() {});
      }
    });
  }

  void _stop() {
    _cameraTimer?.cancel();
    _cameraTimer = null;
    _ticker?.dispose();
    _ticker = null;
    _running = false;
  }

  double? get _avgFrameMs =>
      _frames == 0 ? null : _sumFrameMs / _frames;

  @override
  Widget build(BuildContext context) {
    final avg = _avgFrameMs;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map engine bench (A02)'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<BenchEngine>(
                  segments: const [
                    ButtonSegment(
                      value: BenchEngine.flutterMapRaster,
                      label: Text('flutter_map'),
                      icon: Icon(Icons.grid_on),
                    ),
                    ButtonSegment(
                      value: BenchEngine.mapLibrePlaceholder,
                      label: Text('MapLibre'),
                      icon: Icon(Icons.layers),
                    ),
                  ],
                  selected: {_engine},
                  onSelectionChanged: (s) {
                    _stop();
                    setState(() => _engine = s.first);
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _engine == BenchEngine.flutterMapRaster
                      ? 'Raster stress: Casablanca pan / zoom / rotate ~45s. '
                          'Uses OSM raster tiles for engine cost only (not traffic).'
                      : 'MapLibre native vector not compiled in this build. '
                          'Needs JDK 21 + maplibre_gl dependency, then re-run A/B. '
                          'Also wait for TomTom Navigation Functionality written clearance.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton(
                      onPressed: _running ||
                              _engine == BenchEngine.mapLibrePlaceholder
                          ? null
                          : _start,
                      child: const Text('Start stress'),
                    ),
                    OutlinedButton(
                      onPressed: _running ? () { _stop(); setState(() {}); } : null,
                      child: const Text('Stop'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Frames: $_frames · slow(>22ms): $_slowFrames · '
                  'avg: ${avg == null ? '—' : '${avg.toStringAsFixed(1)} ms'} · '
                  'max: ${_maxFrameMs.toStringAsFixed(1)} ms · '
                  't: ${_elapsed.inSeconds}s',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Also capture: adb shell dumpsys meminfo com.meinloga.my_logan',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(
            child: _engine == BenchEngine.flutterMapRaster
                ? FlutterMap(
                    mapController: _map,
                    options: const MapOptions(
                      initialCenter: _casablanca,
                      initialZoom: 14.5,
                      backgroundColor: Color(0xFFE8EEE9),
                    ),
                    children: [
                      TileLayer(
                        // Public OSM raster for engine microbench only.
                        // Production nav must use licensed TomTom tiles + attribution.
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.meinloga.my_logan.bench',
                        maxZoom: 18,
                        keepBuffer: 1,
                        panBuffer: 0,
                      ),
                      const SimpleAttributionWidget(
                        source: Text('© OpenStreetMap (bench only)'),
                      ),
                    ],
                  )
                : const ColoredBox(
                    color: Color(0xFF1B1F1C),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'MapLibre lane placeholder.\n\n'
                          'Install JDK 21, add maplibre_gl, rebuild, then compare '
                          'avg/max frame ms and dumpsys TOTAL PSS on the A02.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
