/// Модели данных. Время в расписании хранится в минутах от полуночи.
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

  /// Примерное время приёма, минуты от полуночи, отсортированы.
  List<int> times;

  /// С какого дня действует схема (включительно).
  DateTime startDate;

  /// Если задано — схема отменена с этого дня (история сохраняется).
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

/// Отметка о приёме конкретного «слота» (лекарство + плановое время + день).
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

class Food {
  const Food(
    this.name,
    this.kcal100,
    this.portion,
    this.category, {
    this.custom = false,
  });

  final String name;
  final int kcal100;
  final int portion;
  final String category;
  final bool custom;

  Map<String, dynamic> toJson() => {
    'name': name,
    'kcal': kcal100,
    'portion': portion,
    'cat': category,
  };

  factory Food.fromJson(Map<String, dynamic> j) => Food(
    j['name'] as String,
    j['kcal'] as int,
    j['portion'] as int,
    (j['cat'] ?? 'Мои продукты') as String,
    custom: true,
  );
}

class MealItem {
  MealItem({required this.name, required this.grams, required this.kcal100});

  final String name;
  int grams;
  final int kcal100;

  int get kcal => (grams * kcal100 / 100).round();

  Map<String, dynamic> toJson() => {'name': name, 'g': grams, 'k': kcal100};

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
    name: j['name'] as String,
    grams: j['g'] as int,
    kcal100: j['k'] as int,
  );
}

class Meal {
  Meal({
    required this.id,
    required this.at,
    required this.items,
    this.note = '',
  });

  final String id;
  DateTime at;
  List<MealItem> items;
  String note;

  int get kcal => items.fold(0, (s, i) => s + i.kcal);

  String get title {
    final h = at.hour;
    if (h >= 5 && h < 11) return 'Завтрак';
    if (h >= 11 && h < 16) return 'Обед';
    if (h >= 17 && h < 22) return 'Ужин';
    return 'Перекус';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
    'note': note,
  };

  factory Meal.fromJson(Map<String, dynamic> j) => Meal(
    id: j['id'] as String,
    at: DateTime.parse(j['at'] as String).toLocal(),
    items: (j['items'] as List)
        .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    note: (j['note'] ?? '') as String,
  );
}

/// Плановый слот приёма на конкретный день с фактом (если отмечен).
class DoseSlot {
  DoseSlot(this.med, this.day, this.slot, this.intake);

  final Medication med;
  final DateTime day;
  final int slot;
  final Intake? intake;

  bool get taken => intake != null;
  DateTime get planned => day.add(Duration(minutes: slot));
}

/// Сводка дня для тепловой карты.
class DaySummary {
  const DaySummary({
    required this.planned,
    required this.taken,
    required this.kcal,
    required this.meals,
  });

  final int planned;
  final int taken;
  final int kcal;
  final int meals;

  double? get adherence => planned == 0 ? null : taken / planned;
}
