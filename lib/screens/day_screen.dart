import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'meal_editor.dart';

/// Детали дня: сводка + хронология приёмов лекарств и еды.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final slots = store.slotsFor(day);
    final meals = store.mealsFor(day);
    final s = store.summary(day);

    // Единая лента событий по времени.
    final events = <({int minute, Widget child})>[
      for (final sl in slots)
        (
          minute: sl.intake == null
              ? sl.slot
              : sl.intake!.takenAt.hour * 60 + sl.intake!.takenAt.minute,
          child: DoseTile(slot: sl),
        ),
      for (final m in meals)
        (
          minute: m.at.hour * 60 + m.at.minute,
          child: MealTile(meal: m, expanded: true),
        ),
    ]..sort((a, b) => a.minute.compareTo(b.minute));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('d MMMM, EEEE').format(day))),
      floatingActionButton: FloatingActionButton.small(
        tooltip: 'Добавить еду',
        onPressed: () => openMealEditor(context, day: day),
        child: const Icon(Icons.restaurant_outlined),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            children: [
              Row(
                children: [
                  _Big(
                    value: slots.isEmpty
                        ? '—'
                        : '${slots.where((x) => x.taken).length}/${slots.length}',
                    label: 'приёмов',
                  ),
                  _Big(value: '${s.meals}', label: 'раз ели'),
                  _Big(value: '${s.kcal}', label: 'ккал'),
                ],
              ),
              if (slots.isNotEmpty) ...[
                const SizedBox(height: 10),
                HatchProgress(
                  value: slots.where((x) => x.taken).length / slots.length,
                ),
              ],
              if (meals.length > 1) ...[
                const SizedBox(height: 10),
                Text(_gaps(meals), style: t.bodySmall),
              ],
              const SectionLabel('Хронология'),
              if (events.isEmpty)
                const HatchEmpty(text: 'В этот день ничего не отмечено')
              else
                for (var i = 0; i < events.length; i++)
                  _TimelineRow(
                    first: i == 0,
                    last: i == events.length - 1,
                    child: events[i].child,
                  ),
              const SizedBox(height: 8),
              Text(
                'Тап по приёму — отметить или снять; долгое нажатие — изменить время.',
                style: t.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _gaps(List<Meal> meals) {
    final first = meals.first.at, last = meals.last.at;
    final window = last.difference(first);
    final hm = DateFormat.Hm();
    return 'Окно питания: ${hm.format(first)}–${hm.format(last)} '
        '(${window.inHours} ч ${window.inMinutes % 60} мин)';
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.first,
    required this.last,
    required this.child,
  });
  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: CustomPaint(
              painter: _RailPainter(first: first, last: last),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({required this.first, required this.last});
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    const y = 24.0;
    final line = Paint()
      ..color = C.line
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(x, first ? y : 0),
      Offset(x, last ? y : size.height),
      line,
    );
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(0.25);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: 8, height: 8),
      Paint()..color = C.accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.first != first || old.last != last;
}

class _Big extends StatelessWidget {
  const _Big({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: C.accent, width: 2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: t.headlineMedium?.copyWith(color: C.accent, fontSize: 26),
            ),
            Text(label, style: t.bodySmall),
          ],
        ),
      ),
    );
  }
}
