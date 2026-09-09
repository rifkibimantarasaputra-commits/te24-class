import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/course.dart';
import 'settings_store.dart';

/// Scheduler jadwal kuliah TE24.
///
/// Semua perhitungan tanggal/jam dibuat berdasarkan WIB (UTC+7), bukan
/// berdasarkan timezone Windows/Android/iOS. Jadwal kuliah mengikuti HARI
/// setiap minggu, sehingga tanggal akan otomatis bergeser ke minggu berikutnya.
class ReminderScheduler {
  /// Alarm plugin tidak menyediakan weekly repeating alarm yang konsisten
  /// Android + iOS. Karena itu kita membuat alarm one-shot untuk banyak minggu
  /// ke depan. Setiap kali aplikasi dibuka / pengaturan berubah, jadwal akan
  /// direfresh sehingga rentang ke depan selalu diperpanjang lagi.
  static const int weeksToSchedule = 52;

  static const Duration wibOffset = Duration(hours: 7);

  Future<void> requestPermissions() async {
    if (kIsWeb) return;

    if (Platform.isAndroid) {
      await Permission.notification.request();
      await Permission.scheduleExactAlarm.request();
    }

    if (Platform.isIOS) {
      await Permission.notification.request();
      await Permission.backgroundRefresh.request();
    }
  }

  /// Waktu sekarang dalam WIB sebagai instant UTC yang benar.
  ///
  /// Contoh: 09-09-2026 20:00 WIB direpresentasikan sebagai
  /// 09-09-2026 13:00 UTC, sehingga Alarm.set tetap menunjuk ke instant
  /// yang sama walaupun device menggunakan timezone berbeda.
  DateTime _nowWibInstant() {
    return DateTime.now().toUtc();
  }

  /// Mengubah tanggal + jam kalender WIB menjadi instant UTC.
  DateTime _wibDateTime({
    required DateTime wibDate,
    required int hour,
    required int minute,
  }) {
    return DateTime.utc(
      wibDate.year,
      wibDate.month,
      wibDate.day,
      hour,
      minute,
    ).subtract(wibOffset);
  }

  /// Mendapatkan tanggal kalender WIB sekarang.
  DateTime _todayWibCalendar() {
    final wib = DateTime.now().toUtc().add(wibOffset);
    return DateTime(wib.year, wib.month, wib.day);
  }

  Future<void> schedule({
    required AppSettings settings,
    required List<Course> courses,
  }) async {
    if (kIsWeb) return;

    // Semua jadwal lama dibersihkan sebelum membuat jadwal terbaru supaya
    // perubahan reminder/jadwal tidak menghasilkan alarm duplikat.
    await Alarm.stopAll();

    if (!settings.alarmEnabled && !settings.notificationsEnabled) {
      return;
    }

    final nowInstant = _nowWibInstant();
    final todayWib = _todayWibCalendar();

    // Cari hari Senin pada minggu kalender WIB saat ini.
    final monday = todayWib.subtract(
      Duration(days: todayWib.weekday - DateTime.monday),
    );

    for (int week = 0; week < weeksToSchedule; week++) {
      final weekMonday = monday.add(Duration(days: week * 7));

      for (final course in courses) {
        final classDate = weekMonday.add(
          Duration(days: course.weekday - DateTime.monday),
        );

        final startParts = course.start.split(':');
        final startHour = int.parse(startParts[0]);
        final startMinute = int.parse(startParts[1]);

        final endParts = course.end.split(':');
        final endHour = int.parse(endParts[0]);
        final endMinute = int.parse(endParts[1]);

        final classStart = _wibDateTime(
          wibDate: classDate,
          hour: startHour,
          minute: startMinute,
        );

        final classEnd = _wibDateTime(
          wibDate: classDate,
          hour: endHour,
          minute: endMinute,
        );

        final reminderAt = classStart.subtract(
          Duration(minutes: settings.reminderMinutes),
        );

        // Jangan membuat alarm yang waktunya sudah lewat.
        if (!reminderAt.isAfter(nowInstant)) continue;

        // 8 mata kuliah x 52 minggu tetap memiliki ID unik.
        final id = _alarmId(course.id, week);

        await Alarm.set(
          alarmSettings: AlarmSettings(
            id: id,
            dateTime: reminderAt,
            volumeSettings: const VolumeSettings.fixed(volume: 1.0),
            assetAudioPath: null,
            loopAudio: true,
            vibrate: settings.alarmEnabled,
            warningNotificationOnKill: Platform.isIOS,
            androidFullScreenIntent: settings.alarmEnabled,
            androidSnoozeDuration: const Duration(minutes: 5),
            allowSameSecondScheduling: true,
            allowAlarmOverlap: false,
            // Payload memakai instant UTC agar tanggal yang diterima kembali
            // tetap konsisten lintas timezone.
            payload:
                '${course.id}|${classStart.toIso8601String()}|${classEnd.toIso8601String()}',
            notificationSettings: NotificationSettings(
              title: 'TE24 CLASS',
              body:
                  '${course.name}\nKelas dimulai ${settings.reminderMinutes} menit lagi.\n${course.start} – ${course.end} • Ruang ${course.room}',
              stopButton: 'MATIKAN',
              androidSnoozeButton: 'TUNDA 5 MENIT',
              androidStopAlarmOnDismiss: false,
              iconColor: const Color(0xFF2D7DFF),
            ),
          ),
        );
      }
    }
  }

  int _alarmId(int courseId, int week) => 240000 + courseId * 1000 + week;
}
