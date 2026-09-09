class Course {
  final int id;
  final String name;
  final String code;
  final int sks;
  final String lecturer;
  final String day;
  final int weekday;
  final String start;
  final String end;
  final String room;

  const Course({
    required this.id,
    required this.name,
    required this.code,
    required this.sks,
    required this.lecturer,
    required this.day,
    required this.weekday,
    required this.start,
    required this.end,
    required this.room,
  });

  int get startMinutes {
    final p = start.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  int get endMinutes {
    final p = end.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  DateTime startAt(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(start.split(':')[0]),
        int.parse(start.split(':')[1]),
      );

  DateTime endAt(DateTime date) => DateTime(
        date.year,
        date.month,
        date.day,
        int.parse(end.split(':')[0]),
        int.parse(end.split(':')[1]),
      );
}
