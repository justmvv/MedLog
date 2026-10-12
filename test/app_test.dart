import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:medlog/app_version.dart';
import 'package:medlog/main.dart';
import 'package:medlog/models.dart';
import 'package:medlog/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  Intl.defaultLocale = 'ru';
  await initializeDateFormatting('ru');
  return AppStore.load();
}

Medication _med(AppStore s, {DateTime? start}) {
  final m = Medication(
    id: 'm1',
    name: 'Метформин',
    dose: '500 мг',
    times: [8 * 60 + 30, 20 * 60 + 30],
    startDate: start ?? DateTime.now().subtract(const Duration(days: 10)),
  );
  s.upsertMed(m);
  return m;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without --dart-define the build is labeled as debug', () {
    expect(appVersion, isEmpty);
    expect(versionLabel, 'Отладочная сборка');
  });

  test('checking off a dose and the day summary', () async {
    final s = await _store();
    _med(s);
    final yesterday = dayOf(DateTime.now()).subtract(const Duration(days: 1));
    final slots = s.slotsFor(yesterday);
    expect(slots, hasLength(2));
    s.toggle(slots.first);
    final sum = s.summary(yesterday);
    expect(sum.planned, 2);
    expect(sum.taken, 1);
    expect(
      s.slotsFor(yesterday).first.intake!.takenAt,
      yesterday.add(const Duration(minutes: 510)),
    );
    s.toggle(s.slotsFor(yesterday).first);
    expect(s.summary(yesterday).taken, 0);
  });

  test('changing times does not rewrite past days', () async {
    final s = await _store();
    final m = _med(s);
    final past = dayOf(DateTime.now()).subtract(const Duration(days: 3));
    s.toggle(s.slotsFor(past).first);
    s.saveMed(m, name: m.name, dose: m.dose, note: '', times: [9 * 60]);
    expect(s.slotsFor(past).map((e) => e.slot), [510, 1230]);
    expect(s.slotsFor(past).first.taken, isTrue);
    expect(s.slotsFor(DateTime.now()).map((e) => e.slot), [540]);
  });

  test('stopping a schedule keeps its history', () async {
    final s = await _store();
    final m = _med(s);
    s.stopMed(m);
    expect(s.activeMeds, isEmpty);
    final past = dayOf(DateTime.now()).subtract(const Duration(days: 2));
    expect(s.slotsFor(past), hasLength(2));
  });

  test('day summary measures the offset from the planned time', () async {
    final s = await _store();
    _med(s);
    final past = dayOf(DateTime.now()).subtract(const Duration(days: 1));
    final slots = s.slotsFor(past);
    s.toggle(slots[0], at: slots[0].planned.add(const Duration(minutes: 20)));
    s.toggle(
      slots[1],
      at: slots[1].planned.subtract(const Duration(minutes: 10)),
    );
    final sum = s.summary(past);
    expect(sum.taken, 2);
    expect(sum.offsetMinutes, 30);
  });

  testWidgets('medication editor opens from the schedule', (tester) async {
    final s = await tester.runAsync(_store);
    _med(s!);
    await tester.pumpWidget(StoreScope(store: s, child: const MedLogApp()));
    await tester.tap(find.text('Схема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Метформин').last);
    await tester.pumpAndSettle();
    expect(find.text('Завершить'), findsOneWidget);
  });
}
