import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'main.dart';
import 'models.dart';
import 'theme.dart';

final _hm = DateFormat.Hm();

/// A planned dose row with a checkbox.
/// Tap to check/uncheck, long-press to correct the actual time.
class DoseTile extends StatelessWidget {
  const DoseTile({super.key, required this.slot});
  final DoseSlot slot;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final overdue =
        !slot.taken &&
        now.isAfter(slot.planned.add(const Duration(minutes: 60)));
    final t = Theme.of(context).textTheme;

    Future<void> editTime() async {
      final base = slot.intake?.takenAt ?? slot.planned;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(base),
        helpText: 'Фактическое время приёма',
      );
      if (picked == null) return;
      store.setIntakeTime(
        slot,
        DateTime(
          slot.day.year,
          slot.day.month,
          slot.day.day,
          picked.hour,
          picked.minute,
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => store.toggle(slot),
      onLongPress: editTime,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          color: C.paper,
          border: Border.all(
            color: slot.taken
                ? C.soft
                : overdue
                ? C.alert
                : C.line,
            width: 1.3,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '≈ ${hhmm(slot.slot)}',
                    style: t.titleMedium?.copyWith(
                      fontWeight: FontWeight.w300,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Container(width: 1, height: 34, color: C.lineSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.med.name,
                    style: t.titleMedium?.copyWith(
                      decoration: slot.taken
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: C.accent,
                      decorationThickness: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (slot.med.dose.isNotEmpty) slot.med.dose,
                      if (slot.taken)
                        'принято в ${_hm.format(slot.intake!.takenAt)}'
                      else if (overdue)
                        'пропущено?',
                    ].join(' · '),
                    style: t.bodySmall?.copyWith(
                      color: slot.taken
                          ? C.accent
                          : overdue
                          ? C.alert
                          : C.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (slot.taken)
              IconButton(
                tooltip: 'Изменить время',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: C.inkSoft,
                ),
                onPressed: editTime,
              ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: StrokeCheck(checked: slot.taken),
            ),
          ],
        ),
      ),
    );
  }
}
