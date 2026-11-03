import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays short local Darija clips from real maneuver events.
/// Missing assets are logged; we never invent spoken guidance.
class DarijaVoicePlayer {
  DarijaVoicePlayer({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  bool enabled = true;
  double volume = 1.0;
  bool _busy = false;

  static const assetPrefix = 'audio/darija/';

  /// Required owner-supplied recordings (place under assets/audio/darija/).
  static const requiredClips = <String, String>{
    'continue_straight': 'بقا نيشان',
    'turn_left': 'دور على ليسر',
    'turn_right': 'دور على ليمن',
    'in_100_m': 'من بعد مية متر',
    'in_200_m': 'من بعد ميتين متر',
    'in_500_m': 'من بعد خمسمية متر',
    'roundabout_exit_1': 'فالرومبوان، خود الخرجة اللولة',
    'roundabout_exit_2': 'فالرومبوان، خود الخرجة الثانية',
    'roundabout_exit_3': 'فالرومبوان، خود الخرجة التالتة',
    'recalculate': 'عاودنا حسبنا الطريق',
    'arrived': 'وصلتي للوجهة ديالك',
  };

  Future<void> playClip(String clipKey) async {
    if (!enabled || _busy) return;
    final file = '$assetPrefix$clipKey.mp3';
    _busy = true;
    try {
      await _player.stop();
      await _player.setVolume(volume);
      await _player.play(AssetSource(file));
    } catch (e) {
      debugPrint('Darija clip missing or failed ($clipKey): $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
