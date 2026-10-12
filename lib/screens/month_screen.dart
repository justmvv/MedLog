import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models.dart';
import '../theme.dart';
import 'day_screen.dart';

class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key});

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final today = dayOf(DateTime.now());
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = _month.weekday - 1; // Monday = 0
    final days = [
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(_month.year, _month.month, d),
    ];
    final sums = {
      for (final d in days)
        if (!d.isAfter(today)) d: store.summary(d),
    };

    // Month summary
    final planned = sums.values.fold(0, (a, s) => a + s.planned);
    final taken = sums.values.fold(0, (a, s) => a + s.taken);
    final perfect = sums.values
        .where((s) => s.planned > 0 && s.taken == s.planned)
        .length;
    final offset = sums.values.fold(0, (a, s) => a + s.offsetMinutes);
    final canForward = _month.isBefore(DateTime(today.year, today.month));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_month.year}', style: t.labelSmall),
                  Text(
                    toBeginningOfSentenceCase(
                      DateFormat('LLLL').format(_month),
                    ),
                    style: t.headlineMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: canForward ? () => _shift(1) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final w in const ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'])
              Expanded(
                child: Center(
                  child: Text(w.toUpperCase(), style: t.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox(),
            for (final d in days)
              HeatCell(
                day: d,
                summary: sums[d],
                isToday: d == today,
                onTap: d.isAfter(today)
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => DayScreen(day: d)),
                      ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        const _Legend(),
        const SectionLabel('Итоги месяца'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.6,
          children: [
            _Stat(
              value: planned == 0 ? '—' : '${(taken * 100 / planned).round()}%',
              label: 'приёмов выполнено',
            ),
            _Stat(value: '${planned - taken}', label: 'приёмов пропущено'),
            _Stat(value: '$perfect', label: 'дней без пропусков'),
            _Stat(
              value: taken == 0 ? '—' : '±${offset ~/ taken} мин',
              label: 'от планового времени',
            ),
          ],
        ),
      ],
    );
  }
}

/// Heatmap cell. Intensity is shown by hatching density and color;
/// 100% is a solid fill.
class HeatCell extends StatelessWidget {
  const HeatCell({
    super.key,
    required this.day,
    required this.summary,
    required this.isToday,
    this.onTap,
  });

  final DateTime day;
  final DaySummary? summary;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    // value: null means no data, 0..1 is the intensity
    final value = s?.adherence;
    final future = s == null;
    final full = value != null && value >= 0.999;
    final missedAll = value == 0;

    Color border;
    if (future) {
      border = C.lineSoft;
    } else if (value == null) {
      border = C.line;
    } else if (missedAll) {
      border = C.inkSoft;
    } else {
      border = C.ramp(value);
    }

    Widget cell = Container(
      decoration: BoxDecoration(
        color: full ? C.deep : (future ? null : C.paper),
        border: future
            ? null
            : Border.all(color: border, width: isToday ? 2.2 : 1.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: CustomPaint(
        painter: future
            ? DashedBorderPainter(color: C.line)
            : (value != null && !full && !missedAll)
            ? HatchPainter(
                color: C.ramp(value),
                density: 0.15 + value * 0.85,
                strokeWidth: 1 + value * 0.6,
                radius: 4,
              )
            : missedAll
            ? _CrossPainter()
            : null,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Align(
            alignment: Alignment.topLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              color: full || future ? null : C.paper.withValues(alpha: 0.85),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                  color: full
                      ? Colors.white
                      : future
                      ? C.line
                      : C.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (onTap != null) {
      cell = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: cell,
      );
    }
    return Tooltip(message: _tooltip(), child: cell);
  }

  String _tooltip() {
    final s = summary;
    final date = DateFormat('d MMMM').format(day);
    if (s == null) return date;
    return '$date\nприёмы: ${s.taken}/${s.planned}';
  }
}

/// All doses missed: a thin diagonal cross.
class _CrossPainter extends CustomPainter {
  _CrossPainter({this.dy = 4});
  final double dy;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = C.inkSoft
      ..strokeWidth = 1.2;
    final pad = size.width * 0.28;
    canvas.drawLine(
      Offset(pad, pad + dy),
      Offset(size.width - pad, size.height - pad + dy),
      p,
    );
    canvas.drawLine(
      Offset(size.width - pad, pad + dy),
      Offset(pad, size.height - pad + dy),
      p,
    );
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.dy != dy;
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.bodySmall;
    Widget swatch(double v, {bool full = false, bool cross = false}) =>
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: full ? C.deep : C.paper,
            border: Border.all(
              color: cross ? C.inkSoft : C.ramp(v),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: full
              ? null
              : CustomPaint(
                  painter: cross
                      ? _CrossPainter(dy: 0)
                      : HatchPainter(
                          color: C.ramp(v),
                          density: 0.15 + v * 0.85,
                          strokeWidth: 1 + v * 0.6,
                          radius: 3,
                        ),
                ),
        );
    return Row(
      children: [
        swatch(0, cross: true),
        Text(' нет  ', style: t),
        swatch(0.25),
        swatch(0.5),
        swatch(0.8),
        Text(' частично  ', style: t),
        swatch(1, full: true),
        Text(' всё принято', style: t),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: C.accent.withValues(alpha: 0.8), width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: t.titleLarge?.copyWith(
              fontWeight: FontWeight.w300,
              color: C.accent,
            ),
          ),
          Text(label, style: t.bodySmall?.copyWith(height: 1.2)),
        ],
      ),
    );
  }
}
