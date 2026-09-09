import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';

import 'models/course.dart';
import 'models/schedule.dart';
import 'services/reminder_scheduler.dart';
import 'services/settings_store.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

const navy = Color(0xFF123F7A);
const blue = Color(0xFF2166D1);
const sky = Color(0xFFEAF3FF);
const ink = Color(0xFF122B4A);
const muted = Color(0xFF7890AC);
const page = Color(0xFFF7FAFE);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) await Alarm.init();

  final store = SettingsStore();
  final settings = await store.load();
  final scheduler = ReminderScheduler();
  await scheduler.requestPermissions();
  await scheduler.schedule(settings: settings, courses: courses);

  runApp(TE24App(
    settings: settings,
    settingsStore: store,
    scheduler: scheduler,
  ));
}

class TE24App extends StatelessWidget {
  final AppSettings settings;
  final SettingsStore settingsStore;
  final ReminderScheduler scheduler;

  const TE24App({
    super.key,
    required this.settings,
    required this.settingsStore,
    required this.scheduler,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'TE24 CLASS',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: page,
        colorScheme: ColorScheme.fromSeed(seedColor: blue),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: page,
          foregroundColor: ink,
          elevation: 0,
        ),
      ),
      home: MainShell(
        initialSettings: settings,
        settingsStore: settingsStore,
        scheduler: scheduler,
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppSettings initialSettings;
  final SettingsStore settingsStore;
  final ReminderScheduler scheduler;

  const MainShell({
    super.key,
    required this.initialSettings,
    required this.settingsStore,
    required this.scheduler,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  late AppSettings settings;
  DateTime now = _nowWib();
  Timer? timer;
  StreamSubscription<dynamic>? alarmSub;

  @override
  void initState() {
    super.initState();
    settings = widget.initialSettings;
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => now = _nowWib());
    });

    if (!kIsWeb) {
      alarmSub = Alarm.ringing.listen((set) {
        if (!mounted || set.alarms.isEmpty) return;
        final ringing = set.alarms.first;
        final payload = ringing.payload;
        if (payload == null) return;
        final courseId = int.tryParse(payload.split('|').first);
        final course = courses.where((c) => c.id == courseId).firstOrNull;
        if (course == null) return;
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => AlarmScreen(course: course, alarmId: ringing.id),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    alarmSub?.cancel();
    super.dispose();
  }

  Future<void> updateSettings(AppSettings next) async {
    setState(() => settings = next);
    await widget.settingsStore.save(next);
    await widget.scheduler.requestPermissions();
    await widget.scheduler.schedule(settings: next, courses: courses);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(now: now),
      SchedulePage(now: now),
      ReminderPage(now: now, settings: settings),
      SettingsPage(settings: settings, onChanged: updateSettings),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: _BottomBar(
        index: index,
        onChanged: (value) => setState(() => index = value),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _BottomBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE7EEF7))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              _nav(0, Icons.home_rounded, 'Home'),
              _nav(1, Icons.calendar_month_rounded, 'Jadwal'),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => onChanged(2),
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: blue.withOpacity(.25),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          )
                        ],
                      ),
                      child: const Icon(Icons.notifications_rounded,
                          color: Colors.white, size: 25),
                    ),
                  ),
                ),
              ),
              _nav(2, Icons.alarm_rounded, 'Reminder'),
              _nav(3, Icons.person_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(int i, IconData icon, String label) {
    final active = index == i;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(i),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: active ? blue : muted),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? blue : muted)),
          ],
        ),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  final DateTime now;
  const HomePage({super.key, required this.now});

  @override
  Widget build(BuildContext context) {
    final today = courses.where((c) => c.weekday == now.weekday).toList();
    final current = _currentCourse(now);
    final next = _nextCourse(now);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
        children: [
          _topBar(),
          const SizedBox(height: 24),
          Text('Halo!', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: ink)),
          const SizedBox(height: 4),
          Text('${_greeting(now)}, selamat datang kembali 👋', style: const TextStyle(color: muted, fontSize: 13)),
          const SizedBox(height: 18),
          _searchBox(),
          const SizedBox(height: 16),
          _welcomeCard(),
          const SizedBox(height: 24),
          _sectionTitle('Kelas Hari Ini', '${today.length} kelas'),
          const SizedBox(height: 12),
          if (today.isEmpty)
            _emptyCard('Tidak ada jadwal kelas hari ini.')
          else
            ...today.map((c) => _courseTile(context, c, now)),
          const SizedBox(height: 14),
          _nextClassCard(current: current, next: next, now: now),
        ],
      ),
    );
  }

  Widget _topBar() => Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: sky, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.grid_view_rounded, color: navy, size: 22),
          ),
          const Spacer(),
          const Text('TE24 CLASS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .7, color: navy)),
          const Spacer(),
          Stack(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: sky, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.notifications_none_rounded, color: navy),
            ),
            Positioned(right: 8, top: 7, child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFFF4D6D), shape: BoxShape.circle))),
          ]),
        ],
      );
}

class SchedulePage extends StatefulWidget {
  final DateTime now;
  const SchedulePage({super.key, required this.now});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late int selected;

  @override
  void initState() {
    super.initState();
    selected = widget.now.weekday > 6 ? 6 : widget.now.weekday;
  }

  @override
  Widget build(BuildContext context) {
    final dayCourses = courses.where((c) => c.weekday == selected).toList();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          _pageHeader('Jadwal', 'Semua jadwal kuliah TE24 dalam satu tempat.'),
          const SizedBox(height: 20),
          SizedBox(
            height: 72,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              itemBuilder: (_, i) {
                final day = i + 1;
                final active = day == selected;
                return GestureDetector(
                  onTap: () => setState(() => selected = day),
                  child: Container(
                    width: 68,
                    margin: const EdgeInsets.only(right: 9),
                    decoration: BoxDecoration(
                      color: active ? navy : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: active ? navy : const Color(0xFFE4ECF5)),
                      boxShadow: active ? [BoxShadow(color: navy.withOpacity(.16), blurRadius: 16, offset: const Offset(0, 7))] : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_dayShort(day), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white70 : muted)),
                        const SizedBox(height: 5),
                        Text('$day', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: active ? Colors.white : ink)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(_dayName(selected), '${dayCourses.length} kelas'),
          const SizedBox(height: 12),
          if (dayCourses.isEmpty) _emptyCard('Tidak ada kelas pada hari ini.') else ...dayCourses.map((c) => _courseTile(context, c, widget.now)),
        ],
      ),
    );
  }
}

class ReminderPage extends StatelessWidget {
  final DateTime now;
  final AppSettings settings;
  const ReminderPage({super.key, required this.now, required this.settings});

  @override
  Widget build(BuildContext context) {
    final reminders = _nextReminders(now, settings.reminderMinutes);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          _pageHeader('Reminder', 'Jangan sampai kelas berikutnya terlewat.'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [navy, blue]),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: blue.withOpacity(.18), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Row(children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withOpacity(.14), shape: BoxShape.circle), child: const Icon(Icons.notifications_active_rounded, color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Reminder aktif', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 3),
                Text('${settings.reminderMinutes} menit sebelum kelas', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
              const Icon(Icons.check_circle_rounded, color: Colors.white),
            ]),
          ),
          const SizedBox(height: 22),
          _sectionTitle('Akan Datang', '${reminders.length} reminder'),
          const SizedBox(height: 12),
          ...reminders.map((r) => _reminderTile(r.$1, r.$2, r.$3)),
        ],
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final AppSettings settings;
  final Future<void> Function(AppSettings) onChanged;
  const SettingsPage({super.key, required this.settings, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 28),
        children: [
          _pageHeader('Profil', 'Atur pengalaman TE24 CLASS kamu.'),
          const SizedBox(height: 20),
          _profileCard(),
          const SizedBox(height: 20),
          _settingCard(
            icon: Icons.notifications_rounded,
            title: 'Notification',
            subtitle: 'Terima pengingat sebelum kelas dimulai.',
            trailing: Switch.adaptive(
              value: settings.notificationsEnabled,
              onChanged: (v) => onChanged(AppSettings(notificationsEnabled: v, alarmEnabled: settings.alarmEnabled, reminderMinutes: settings.reminderMinutes)),
            ),
          ),
          const SizedBox(height: 10),
          _settingCard(
            icon: Icons.alarm_rounded,
            title: 'Alarm suara',
            subtitle: 'Bunyikan alarm saat waktu reminder tiba.',
            trailing: Switch.adaptive(
              value: settings.alarmEnabled,
              onChanged: (v) => onChanged(AppSettings(notificationsEnabled: settings.notificationsEnabled, alarmEnabled: v, reminderMinutes: settings.reminderMinutes)),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ingatkan saya', style: TextStyle(color: ink, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [60, 30, 15, 5].map((m) {
                final active = settings.reminderMinutes == m;
                return ChoiceChip(
                  label: Text('$m menit'),
                  selected: active,
                  onSelected: (_) => onChanged(AppSettings(notificationsEnabled: settings.notificationsEnabled, alarmEnabled: settings.alarmEnabled, reminderMinutes: m)),
                  selectedColor: sky,
                  backgroundColor: const Color(0xFFF5F8FC),
                  side: BorderSide(color: active ? blue : const Color(0xFFE3EAF3)),
                  labelStyle: TextStyle(color: active ? blue : muted, fontWeight: FontWeight.w800),
                  showCheckmark: false,
                );
              }).toList()),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            _stat('8', 'Mata kuliah'),
            const SizedBox(width: 10),
            _stat('20', 'Total SKS'),
            const SizedBox(width: 10),
            _stat('TE24', 'Class'),
          ]),
        ],
      ),
    );
  }

  Widget _profileCard() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [navy, blue]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: navy.withOpacity(.22), blurRadius: 26, offset: const Offset(0, 12))],
        ),
        child: Column(children: [
          Row(children: [
            Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.person_rounded, color: navy, size: 36)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Mahasiswa TE24', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
              SizedBox(height: 4),
              Text('TE24 • Teknik Komputer', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withOpacity(.14), shape: BoxShape.circle), child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16)),
          ]),
          const SizedBox(height: 20),
          Container(height: 1, color: Colors.white.withOpacity(.14)),
          const SizedBox(height: 16),
          const Row(children: [
            _ProfileStat('8', 'Mata kuliah'),
            _ProfileStat('20', 'SKS'),
            _ProfileStat('100%', 'Reminder'),
          ]),
        ]),
      );

  Widget _stat(String value, String label) => Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 15), decoration: _cardDecoration(), child: Column(children: [Text(value, style: const TextStyle(color: navy, fontWeight: FontWeight.w900, fontSize: 18)), const SizedBox(height: 2), Text(label, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700))])));
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  const _ProfileStat(this.value, this.label);
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10))]));
}

class AlarmScreen extends StatelessWidget {
  final Course course;
  final int alarmId;
  const AlarmScreen({super.key, required this.course, required this.alarmId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 92, height: 92, decoration: BoxDecoration(color: Colors.white.withOpacity(.13), shape: BoxShape.circle), child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 44)),
              const SizedBox(height: 28),
              const Text('TE24 CLASS', style: TextStyle(color: Colors.white70, letterSpacing: 3, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('Waktunya kelas!', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text(course.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 6),
              Text('${course.start} – ${course.end} • Ruang ${course.room}', style: const TextStyle(color: Colors.white54)),
              const SizedBox(height: 34),
              SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: () async { if (!kIsWeb) await Alarm.stop(alarmId); if (context.mounted) Navigator.pop(context); }, style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: navy, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: const Text('MATIKAN ALARM', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5)))),
            ]),
          ),
        ),
      ),
    );
  }
}

class CourseDetailPage extends StatelessWidget {
  final Course course;
  final DateTime now;
  const CourseDetailPage({super.key, required this.course, required this.now});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: page,
      appBar: AppBar(title: const Text('Detail Kelas', style: TextStyle(fontWeight: FontWeight.w900)), centerTitle: false),
      body: ListView(padding: const EdgeInsets.fromLTRB(22, 8, 22, 28), children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [navy, blue]), borderRadius: BorderRadius.circular(28)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(10)), child: Text(course.code, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800))),
          const SizedBox(height: 22),
          Text(course.name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(course.lecturer, style: const TextStyle(color: Colors.white70)),
        ])),
        const SizedBox(height: 14),
        _detailRow(Icons.calendar_today_rounded, 'Hari', course.day),
        _detailRow(Icons.schedule_rounded, 'Waktu', '${course.start} – ${course.end}'),
        _detailRow(Icons.meeting_room_rounded, 'Ruang', course.room),
        _detailRow(Icons.school_rounded, 'SKS', '${course.sks} SKS'),
      ]),
    );
  }
}

Widget _detailRow(IconData icon, String title, String value) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(17),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: sky,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: navy, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _searchBox() {
  return Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE6EDF6)),
    ),
    child: const Row(
      children: [
        Icon(Icons.search_rounded, color: navy, size: 21),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Cari kelas, materi, atau tugas...',
            style: TextStyle(
              color: Color(0xFF9AAEC5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _welcomeCard() {
  return Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 12, 17),
    decoration: BoxDecoration(
      color: sky,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat Datang\ndi TE24 CLASS',
                style: TextStyle(
                  color: navy,
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Belajar lebih mudah,\nlebih terarah, lebih baik.',
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 102,
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.laptop_mac_rounded, size: 48, color: blue),
        ),
      ],
    ),
  );
}

Widget _nextClassCard({
  required Course? current,
  required Course? next,
  required DateTime now,
}) {
  final course = current ?? next;
  if (course == null) return _emptyCard('Tidak ada kelas berikutnya.');

  final date = _dateForWeekday(now, course.weekday);
  final target = current != null ? course.endAt(date) : course.startAt(date);
  final diff = target.difference(now);

  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE2EAF3)),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: sky,
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(Icons.timelapse_rounded, color: blue),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                current != null ? 'SEDANG BERLANGSUNG' : 'KELAS BERIKUTNYA',
                style: const TextStyle(
                  color: blue,
                  fontSize: 9,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${course.start} – ${course.end} • Ruang ${course.room}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
        Text(
          _durationText(diff),
          style: const TextStyle(
            color: navy,
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );
}

Widget _courseTile(BuildContext context, Course course, DateTime now) {
  final status = _courseStatus(course, now);
  final active = status == 'BERLANGSUNG';

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseDetailPage(course: course, now: now),
        ),
      );
    },
    borderRadius: BorderRadius.circular(20),
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.start,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  course.end,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: active ? blue : const Color(0xFFD8E7F8),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ruang ${course.room} • ${course.day}',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: active ? sky : const Color(0xFFF4F7FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: active ? blue : muted,
                fontSize: 8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _reminderTile(Course course, DateTime reminderAt, bool active) {
  return Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(15),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: sky,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.notifications_active_outlined, color: blue),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${course.day} • ${_formatTime(reminderAt)} • Ruang ${course.room}',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
        Text(
          active ? 'AKTIF' : 'NONAKTIF',
          style: TextStyle(
            color: active ? blue : muted,
            fontSize: 8,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

Widget _settingCard({
  required IconData icon,
  required String title,
  required String subtitle,
  required Widget trailing,
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(15, 13, 10, 13),
    decoration: _cardDecoration(),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: sky,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: navy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
        trailing,
      ],
    ),
  );
}

Widget _pageHeader(String title, String subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          color: ink,
          fontSize: 29,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 5),
      Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
    ],
  );
}

Widget _sectionTitle(String title, String trailing) {
  return Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: ink,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      Text(
        trailing,
        style: const TextStyle(
          color: blue,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

Widget _emptyCard(String text) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: _cardDecoration(),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

BoxDecoration _cardDecoration() => BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE3EAF3)), boxShadow: [BoxShadow(color: const Color(0xFF163B68).withOpacity(.035), blurRadius: 16, offset: const Offset(0, 6))]);
DateTime _nowWib() => DateTime.now().toUtc().add(const Duration(hours: 7));

String _greeting(DateTime now) => now.hour < 11 ? 'Selamat pagi' : now.hour < 15 ? 'Selamat siang' : now.hour < 18 ? 'Selamat sore' : 'Selamat malam';
String _dateLabel(DateTime date) => '${_dayName(date.weekday)}, ${date.day} ${_monthName(date.month)} ${date.year}';
String _dayName(int day) => const ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'][day];
String _dayShort(int day) => const ['', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'][day];
String _monthName(int month) => const ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'][month];
String _formatTime(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _durationText(Duration d) { final m = d.inMinutes.abs(); if (m < 60) return '${m}m'; final h = m ~/ 60; final min = m % 60; return min == 0 ? '${h}j' : '${h}j ${min}m'; }
DateTime _dateForWeekday(DateTime now, int weekday) => DateTime(now.year, now.month, now.day).add(Duration(days: weekday - now.weekday));

Course? _currentCourse(DateTime now) { for (final c in courses) { if (c.weekday != now.weekday) continue; final s = c.startAt(now); final e = c.endAt(now); if (!now.isBefore(s) && now.isBefore(e)) return c; } return null; }
Course? _nextCourse(DateTime now) { final list = <MapEntry<DateTime, Course>>[]; for (final c in courses) { var d = _dateForWeekday(now, c.weekday); var start = c.startAt(d); if (!start.isAfter(now)) { d = d.add(const Duration(days: 7)); start = c.startAt(d); } list.add(MapEntry(start, c)); } list.sort((a,b) => a.key.compareTo(b.key)); return list.isEmpty ? null : list.first.value; }
String _courseStatus(Course c, DateTime now) { if (c.weekday != now.weekday) return 'TERJADWAL'; final s = c.startAt(now); final e = c.endAt(now); if (!now.isBefore(s) && now.isBefore(e)) return 'BERLANGSUNG'; if (now.isAfter(e)) return 'SELESAI'; return 'BERIKUTNYA'; }

List<(Course, DateTime, bool)> _nextReminders(DateTime now, int minutes) {
  final list = <(Course, DateTime, bool, DateTime)>[];
  for (final c in courses) {
    var date = _dateForWeekday(now, c.weekday);
    var start = c.startAt(date);
    if (!start.isAfter(now)) { date = date.add(const Duration(days: 7)); start = c.startAt(date); }
    final reminder = start.subtract(Duration(minutes: minutes));
    list.add((c, reminder, true, start));
  }
  list.sort((a,b) => a.$4.compareTo(b.$4));
  return list.take(6).map((x) => (x.$1, x.$2, x.$3)).toList();
}
