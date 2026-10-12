import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:med_cross/app_version.dart';
import 'package:med_cross/main.dart';
import 'package:med_cross/models.dart';
import 'package:med_cross/store.dart';
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

  test('без --dart-define сборка подписана как отладочная', () {
    expect(appVersion, isEmpty);
    expect(versionLabel, 'Отладочная сборка');
  });

  test('отметка приёма и сводка дня', () async {
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

  test('смена времени не искажает прошлые дни', () async {
    final s = await _store();
    final m = _med(s);
    final past = dayOf(DateTime.now()).subtract(const Duration(days: 3));
    s.toggle(s.slotsFor(past).first);
    s.saveMed(m, name: m.name, dose: m.dose, note: '', times: [9 * 60]);
    expect(s.slotsFor(past).map((e) => e.slot), [510, 1230]);
    expect(s.slotsFor(past).first.taken, isTrue);
    expect(s.slotsFor(DateTime.now()).map((e) => e.slot), [540]);
  });

  test('завершение схемы сохраняет историю', () async {
    final s = await _store();
    final m = _med(s);
    s.stopMed(m);
    expect(s.activeMeds, isEmpty);
    final past = dayOf(DateTime.now()).subtract(const Duration(days: 2));
    expect(s.slotsFor(past), hasLength(2));
  });

  test('поиск по справочнику калорий', () async {
    final s = await _store();
    expect(s.searchFoods('греч').first.name, 'Гречка варёная');
    final meal = Meal(
      id: 'x',
      at: DateTime.now(),
      items: [MealItem(name: 'Гречка варёная', grams: 200, kcal100: 110)],
    );
    s.upsertMeal(meal);
    expect(s.summary(DateTime.now()).kcal, 220);
  });

  testWidgets('редактор лекарства открывается из схемы', (tester) async {
    final s = await tester.runAsync(_store);
    _med(s!);
    await tester.pumpWidget(StoreScope(store: s, child: const MedCrossApp()));
    await tester.tap(find.text('Схема'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Метформин').last);
    await tester.pumpAndSettle();
    expect(find.text('Завершить'), findsOneWidget);
  });
}
