import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// All app state. Stored locally (in the PWA, in localStorage).
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  static const _kMeds = 'meds.v1';
  static const _kIntakes = 'intakes.v1';

  final SharedPreferences _prefs;

  final List<Medication> meds = [];
  final Map<String, Intake> _intakes = {};

  static Future<AppStore> load() async {
    final s = AppStore._(await SharedPreferences.getInstance());
    s._read();
    return s;
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
  }

  Future<void> _save(String key, Iterable<Object> items) =>
      _prefs.setString(key, jsonEncode(items.toList()));

  void _commit({bool m = false, bool i = false}) {
    if (m) _save(_kMeds, meds.map((e) => e.toJson()));
    if (i) _save(_kIntakes, _intakes.values.map((e) => e.toJson()));
    notifyListeners();
  }

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${Random().nextInt(1 << 20).toRadixString(36)}';

  // ── Medications ────────────────────────────────────────────

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

  /// Saves schedule changes. If the dose times changed and the schedule
  /// already has past days, the old version is closed as of today and the new
  /// one starts today, so the history of past days stays intact.
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
    // Move today's intakes to the new version when the time still exists.
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

  /// Stops the schedule from today on; past days stay in the history.
  void stopMed(Medication med) {
    final today = dayOf(DateTime.now());
    if (!dayOf(med.startDate).isBefore(today)) {
      // Created today, so there is no history: delete it entirely.
      meds.removeWhere((m) => m.id == med.id);
      _intakes.removeWhere((_, v) => v.medId == med.id);
      _commit(m: true, i: true);
      return;
    }
    med.endDate = today;
    _intakes.removeWhere((_, v) => v.medId == med.id && !v.day.isBefore(today));
    _commit(m: true, i: true);
  }

  // ── Intakes ────────────────────────────────────────────────

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
      // For past days, default to the planned time.
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

  // ── Summaries ──────────────────────────────────────────────

  /// For today, only doses that are already due (or taken) count; otherwise
  /// the day would look "missed" in the morning.
  DaySummary summary(DateTime day) {
    final now = DateTime.now();
    final slots = slotsFor(
      day,
    ).where((s) => s.taken || !s.planned.isAfter(now)).toList();
    final taken = slots.where((s) => s.taken);
    return DaySummary(
      planned: slots.length,
      taken: taken.length,
      offsetMinutes: taken.fold(
        0,
        (sum, s) =>
            sum + s.intake!.takenAt.difference(s.planned).inMinutes.abs(),
      ),
    );
  }
}
