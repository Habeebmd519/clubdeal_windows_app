import 'package:shared_preferences/shared_preferences.dart';

class AlertSoundService {
  static const _pathKey = 'desktop_alert_sound';
  static const _enabledKey = 'desktop_alert_enabled';

  bool _enabled = true;

  bool get enabled => _enabled;

  Future<String?> customSound() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? true;
    return prefs.getString(_pathKey);
  }

  Future<void> saveCustomSound(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pathKey, path);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pathKey);
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
  }

  Future<void> playPreview() async {
    // Keep this service platform-neutral. Add audioplayers/Windows playback
    // here after selecting the exact Windows audio package.
    if (!_enabled) return;
  }
}
