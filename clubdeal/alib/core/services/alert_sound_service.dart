import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertSoundService {
  AlertSoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  static const String _customSoundKey = 'custom_order_alert_sound';
  static const String _enabledKey = 'order_alerts_enabled';

  bool _enabled = true;
  bool get enabled => _enabled;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> playNewOrder() async {
    if (!_enabled) return;
    await _play(await customSound());
  }

  Future<void> playPreview() async => _play(await customSound());

  Future<void> _play(String? customPath) async {
    try {
      await _player.stop();
      if (customPath != null && customPath.isNotEmpty) {
        await _player.play(DeviceFileSource(customPath));
      } else {
        await _player.play(AssetSource('sound/alert.mp3'));
      }
    } catch (_) {
      // If the optional MP3 asset/custom file is missing, use Windows' alert.
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // Audio must never interrupt order processing.
      }
    }
  }

  Future<void> saveCustomSound(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customSoundKey, path);
  }

  Future<String?> customSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customSoundKey);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customSoundKey);
  }

  Future<void> dispose() async => _player.dispose();
}
