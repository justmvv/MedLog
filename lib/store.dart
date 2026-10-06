import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Всё состояние приложения. Хранится локально (в PWA — в localStorage).
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  static const _kMeds = 'meds.v1';
  static const _kIntakes = 'intakes.v1';
  static const _kMeals = 'meals.v1';
  static const _kFoods = 'foods.custom.v1';

  final SharedPreferences _prefs;

  final List<Medication> meds = [];
  final Map<String, Intake> _intakes = {};
  final List<Meal> meals = [];
  final List<Food> _builtinFoods = [];
  final List<Food> customFoods = [];

  static Future<AppStore> load() async {
    final s = AppStore._(await SharedPreferences.getInstance());
    await s._loadFoods();
    s._read();
    return s;
  }

  Future<void> _loadFoods() async {
    final raw =
        jsonDecode(await rootBundle.loadString('assets/foods.json'))
            as Map<String, dynamic>;
    for (final f in raw['foods'] as List) {
      final l = f as List;
      _builtinFoods.add(
        Food(l[0] as String, l[1] as int, l[2] as int, l[3] as String),
      );
    }
  }

  List<dynamic> _list(String key) {
    final v = _prefs.getString(key);
    if (v == null) return const [];
    try {
      return jsonDecode(v) as List;
    } catch (_) {
      return const [];
    }
  }

  void _read() {
    meds.addAll(
      _list(_kMeds).map((e) => Medication.fromJson(e as Map<String, dynamic>)),
    );
    for (final e in _list(_kIntakes)) {
      final i = Intake.fromJson(e as Map<String, dynamic>);
      _intakes[i.key] = i;
    }
    meals.addAll(
      _list(_kMeals).map((e) => Meal.fromJson(e as Map<String, dynamic>)),
    );
    meals.sort((a, b) => a.at.compareTo(b.at));
    customFoods.addAll(
      _list(_kFoods).map((e) => Food.fromJson(e as Map<String, dynamic>)),
    );
  }

  Future<void> _save(String key, Iterable<Object> items) =>
      _prefs.setString(key, jsonEncode(items.toList()));

  void _commit({
    bool m = false,
    bool i = false,
    bool f = false,
    bool c = false,
  }) {
    if (m) _save(_kMeds, meds.map((e) => e.toJson()));
    if (i) _save(_kIntakes, _intakes.values.map((e) => e.toJson()));
    if (f) _save(_kMeals, meals.map((e) => e.toJson()));
    if (c) _save(_kFoods, customFoods.map((e) => e.toJson()));
    notifyListeners();
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  // ── Лекарства ──────────────────────────────────────────────

  List<Medication> get activeMeds =>
      meds.where((m) => m.activeOn(DateTime.now())).toList();

  void upsertMed(Medication med) {
    med.times.sort();
    final idx = meds.indexWhere((m) => m.id == med.id);
    if (idx < 0) {
      meds.add(med);
    } else {
      meds[idx] = med;
    }
    _commit(m: true);
  }

  /// Сохранить изменения схемы. Если поменялось время приёмов, а у схемы
  /// уже есть прошлые дни — старая версия закрывается сегодняшним днём,
  /// а с сегодня действует новая. Так история прошлых дней не искажается.
  void saveMed(
    Medication med, {
    required String name,
    required String dose,
    required String note,
    required List<int> times,
  }) {
    times = [...times]..sort();
    final today = dayOf(DateTime.now());
    final timesChanged = med.times.join(',') != times.join(',');
    final exists = meds.any((m) => m.id == med.id);
    if (!exists || !timesChanged || !dayOf(med.startDate).isBefore(today)) {
      med
        ..name = name
        ..dose = dose
        ..note = note
        ..times = times;
      upsertMed(med);
      return;
    }
    final next = Medication(
      id: newId(),
      name: name,
      dose: dose,
      note: note,
      times: times,
      startDate: today,
    );
    med.endDate = today;
    // Переносим сегодняшние отметки на новую версию, если время совпадает.
    final todays = _intakes.values
        .where((i) => i.medId == med.id && !i.day.isBefore(today))
        .toList();
    for (final i in todays) {
      _intakes.remove(i.key);
      if (times.contains(i.slot)) {
        final moved = Intake(
          medId: next.id,
          day: i.day,
          slot: i.slot,
          takenAt: i.takenAt,
        );
        _intakes[moved.key] = moved;
      }
    }
    meds.add(next);
    _commit(m: true, i: true);
  }

  /// Отменить схему с сегодняшнего дня; прошлые дни остаются в истории.
  void stopMed(Medication med) {
    final today = dayOf(DateTime.now());
    if (!dayOf(med.startDate).isBefore(today)) {
      // Схема заведена сегодня — истории нет, удаляем полностью.
      meds.removeWhere((m) => m.id == med.id);
      _intakes.removeWhere((_, v) => v.medId == med.id);
      _commit(m: true, i: true);
      return;
    }
    med.endDate = today;
    _intakes.removeWhere((_, v) => v.medId == med.id && !v.day.isBefore(today));
    _commit(m: true, i: true);
  }

  // ── Приёмы ─────────────────────────────────────────────────

  List<DoseSlot> slotsFor(DateTime day) {
    final d = dayOf(day);
    final out = <DoseSlot>[];
    for (final m in meds) {
      if (!m.activeOn(d)) continue;
      for (final t in m.times) {
        out.add(DoseSlot(m, d, t, _intakes[Intake.slotKey(m.id, d, t)]));
      }
    }
    out.sort(
      (a, b) => a.slot != b.slot
          ? a.slot.compareTo(b.slot)
          : a.med.name.compareTo(b.med.name),
    );
    return out;
  }

  void toggle(DoseSlot s, {DateTime? at}) {
    final key = Intake.slotKey(s.med.id, s.day, s.slot);
    if (_intakes.containsKey(key)) {
      _intakes.remove(key);
    } else {
      final now = DateTime.now();
      // Для прошлых дней по умолчанию ставим плановое время.
      final when = at ?? (dayOf(now) == s.day ? now : s.planned);
      _intakes[key] = Intake(
        medId: s.med.id,
        day: s.day,
        slot: s.slot,
        takenAt: when,
      );
    }
    _commit(i: true);
  }

  void setIntakeTime(DoseSlot s, DateTime at) {
    final key = Intake.slotKey(s.med.id, s.day, s.slot);
    _intakes[key] = Intake(
      medId: s.med.id,
      day: s.day,
      slot: s.slot,
      takenAt: at,
    );
    _commit(i: true);
  }

  // ── Еда ────────────────────────────────────────────────────

  List<Meal> mealsFor(DateTime day) {
    final d = dayOf(day);
    return meals.where((m) => dayOf(m.at) == d).toList();
  }

  void upsertMeal(Meal meal) {
    meals.removeWhere((m) => m.id == meal.id);
    meals.add(meal);
    meals.sort((a, b) => a.at.compareTo(b.at));
    _commit(f: true);
  }

  void deleteMeal(Meal meal) {
    meals.removeWhere((m) => m.id == meal.id);
    _commit(f: true);
  }

  // ── Справочник калорий ─────────────────────────────────────

  List<Food> get allFoods => [...customFoods, ..._builtinFoods];

  List<Food> searchFoods(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return allFoods;
    final starts = <Food>[], contains = <Food>[];
    for (final f in allFoods) {
      final n = f.name.toLowerCase();
      if (n.startsWith(query)) {
        starts.add(f);
      } else if (n.contains(query) ||
          f.category.toLowerCase().contains(query)) {
        contains.add(f);
      }
    }
    return [...starts, ...contains];
  }

  /// Часто используемые продукты — по истории приёмов пищи.
  List<Food> get frequentFoods {
    final counts = <String, int>{};
    for (final m in meals) {
      for (final i in m.items) {
        counts[i.name] = (counts[i.name] ?? 0) + 1;
      }
    }
    final byName = {for (final f in allFoods) f.name: f};
    final names = counts.keys.where(byName.containsKey).toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return names.take(8).map((n) => byName[n]!).toList();
  }

  void addCustomFood(Food f) {
    customFoods.removeWhere((e) => e.name == f.name);
    customFoods.insert(0, f);
    _commit(c: true);
  }

  // ── Сводки ─────────────────────────────────────────────────

  /// Для сегодняшнего дня учитываются только уже наступившие (или отмеченные)
  /// приёмы — иначе утром день выглядел бы «пропущенным».
  DaySummary summary(DateTime day) {
    final now = DateTime.now();
    final slots = slotsFor(
      day,
    ).where((s) => s.taken || !s.planned.isAfter(now)).toList();
    final ms = mealsFor(day);
    return DaySummary(
      planned: slots.length,
      taken: slots.where((s) => s.taken).length,
      kcal: ms.fold(0, (s, m) => s + m.kcal),
      meals: ms.length,
    );
  }
}
