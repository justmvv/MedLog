import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

/// Day details: summary plus a timeline of doses.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final slots = store.slotsFor(day);
    final s = store.summary(day);

    // Doses ordered by the actual time (planned time if not taken).
    final events = <({int minute, Widget child})>[
      for (final sl in slots)
        (
          minute: sl.intake == null
              ? sl.slot
              : sl.intake!.takenAt.hour * 60 + sl.intake!.takenAt.minute,
          child: DoseTile(slot: sl),
        ),
    ]..sort((a, b) => a.minute.compareTo(b.minute));

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('d MMMM, EEEE').format(day))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  _Big(
                    value: slots.isEmpty
                        ? '—'
                        : '${slots.where((x) => x.taken).length}/${slots.length}',
                    label: 'приёмов',
                  ),
                  _Big(value: '${s.planned - s.taken}', label: 'пропущено'),
                  _Big(
                    value: s.taken == 0
                        ? '—'
                        : '±${s.offsetMinutes ~/ s.taken}',
                    label: 'мин от плана',
                  ),
                ],
              ),
              if (slots.isNotEmpty) ...[
                const SizedBox(height: 10),
                HatchProgress(
                  value: slots.where((x) => x.taken).length / slots.length,
                ),
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
