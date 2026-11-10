import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlertSoundService {
  AlertSoundService({AudioPlayer? player}) : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  static const String _customSoundKey = 'custom_order_alert_sound';

  bool _enabled = true;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
  }

  // Play alert for a new order.
  Future<void> playNewOrder() async {
    if (!_enabled) return;

    final customPath = await customSound();

    await _play(customPath);
  }

  // Preview the currently selected alert sound.
  Future<void> playPreview() async {
    final customPath = await customSound();
    await _play(customPath);
  }

  // Internal audio playback.
  Future<void> _play(String? customPath) async {
    try {
      await _player.stop();

      if (customPath != null && customPath.isNotEmpty) {
        await _player.play(DeviceFileSource(customPath));
      } else {
        await _player.play(AssetSource('sound/alert.mp3'));
      }
    } catch (e) {
      // Keep audio errors from crashing the application.
      // Replace with your app logger if available.
    }
  }

  // Save custom sound path.
  Future<void> saveCustomSound(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customSoundKey, path);
  }

  // Get custom sound path.
  Future<String?> customSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customSoundKey);
  }

  // Restore default sound.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customSoundKey);
  }

  // Release audio resources.
  Future<void> dispose() async {
    await _player.dispose();
  }
}
