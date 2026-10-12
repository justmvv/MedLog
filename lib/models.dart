/// Data models. Schedule times are stored as minutes since midnight.
library;

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String hhmm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class Medication {
  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.times,
    required this.startDate,
    this.endDate,
    this.note = '',
  });

  final String id;
  String name;
  String dose;
  String note;

  /// Approximate dose times, minutes since midnight, sorted.
  List<int> times;

  /// First day the schedule applies (inclusive).
  DateTime startDate;

  /// If set, the schedule is stopped from this day on (history is kept).
  DateTime? endDate;

  bool activeOn(DateTime day) {
    final d = dayOf(day);
    if (d.isBefore(dayOf(startDate))) return false;
    if (endDate != null && !d.isBefore(dayOf(endDate!))) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'note': note,
    'times': times,
    'start': dayKey(startDate),
    if (endDate != null) 'end': dayKey(endDate!),
  };

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
    id: j['id'] as String,
    name: j['name'] as String,
    dose: (j['dose'] ?? '') as String,
    note: (j['note'] ?? '') as String,
    times: (j['times'] as List).cast<int>()..sort(),
    startDate: DateTime.parse(j['start'] as String),
    endDate: j['end'] == null ? null : DateTime.parse(j['end'] as String),
  );
}

/// A taken dose for a specific slot (medication + planned time + day).
class Intake {
  Intake({
    required this.medId,
    required this.day,
    required this.slot,
    required this.takenAt,
  });

  final String medId;
  final DateTime day;
  final int slot;
  final DateTime takenAt;

  String get key => slotKey(medId, day, slot);

  static String slotKey(String medId, DateTime day, int slot) =>
      '$medId|${dayKey(day)}|$slot';

  Map<String, dynamic> toJson() => {
    'med': medId,
    'day': dayKey(day),
    'slot': slot,
    'at': takenAt.toIso8601String(),
  };

  factory Intake.fromJson(Map<String, dynamic> j) => Intake(
    medId: j['med'] as String,
    day: DateTime.parse(j['day'] as String),
    slot: j['slot'] as int,
    takenAt: DateTime.parse(j['at'] as String).toLocal(),
  );
}

/// A planned dose slot on a given day, with the intake if it was taken.
class DoseSlot {
  DoseSlot(this.med, this.day, this.slot, this.intake);

  final Medication med;
  final DateTime day;
  final int slot;
  final Intake? intake;

  bool get taken => intake != null;
  DateTime get planned => day.add(Duration(minutes: slot));
}

/// Per-day summary for the heatmap.
class DaySummary {
  const DaySummary({
    required this.planned,
    required this.taken,
    required this.offsetMinutes,
  });

  final int planned;
  final int taken;

  /// Sum of |actual − planned| over taken doses, in minutes.
  final int offsetMinutes;

  double? get adherence => planned == 0 ? null : taken / planned;
}
