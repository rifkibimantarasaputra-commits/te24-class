import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool notificationsEnabled;
  final bool alarmEnabled;
  final int reminderMinutes;

  const AppSettings({
    required this.notificationsEnabled,
    required this.alarmEnabled,
    required this.reminderMinutes,
  });

  static const defaults = AppSettings(
    notificationsEnabled: true,
    alarmEnabled: true,
    reminderMinutes: 30,
  );
}

class SettingsStore {
  static const _notificationsKey = 'notifications_enabled';
  static const _alarmKey = 'alarm_enabled';
  static const _reminderKey = 'reminder_minutes';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<AppSettings> load() async {
    return AppSettings(
      notificationsEnabled:
          await _prefs.getBool(_notificationsKey) ?? true,
      alarmEnabled: await _prefs.getBool(_alarmKey) ?? true,
      reminderMinutes: await _prefs.getInt(_reminderKey) ?? 30,
    );
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setBool(
      _notificationsKey,
      settings.notificationsEnabled,
    );
    await _prefs.setBool(_alarmKey, settings.alarmEnabled);
    await _prefs.setInt(_reminderKey, settings.reminderMinutes);
  }
}
