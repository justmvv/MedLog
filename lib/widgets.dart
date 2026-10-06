import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'main.dart';
import 'models.dart';
import 'screens/meal_editor.dart';
import 'theme.dart';

final _hm = DateFormat.Hm();

/// Строка планового приёма с чек-боксом.
/// Тап — отметить/снять, долгое нажатие — поправить фактическое время.
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

/// Карточка приёма пищи.
class MealTile extends StatelessWidget {
  const MealTile({super.key, required this.meal, this.expanded = false});
  final Meal meal;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => openMealEditor(context, meal: meal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: C.paper,
          border: Border.all(color: C.line, width: 1.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    _hm.format(meal.at),
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w300),
                  ),
                ),
                Container(width: 1, height: 20, color: C.lineSoft),
                const SizedBox(width: 12),
                Expanded(child: Text(meal.title, style: t.titleMedium)),
                if (meal.items.isNotEmpty)
                  Text(
                    '${meal.kcal} ккал',
                    style: t.titleMedium?.copyWith(color: C.accent),
                  ),
              ],
            ),
            if (meal.items.isNotEmpty || meal.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 67, top: 4),
                child: expanded
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final i in meal.items)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(i.name, style: t.bodyMedium),
                                  ),
                                  Text(
                                    '${i.grams} г  ·  ${i.kcal} ккал',
                                    style: t.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          if (meal.note.isNotEmpty)
                            Text(
                              meal.note,
                              style: t.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      )
                    : Text(
                        [
                          ...meal.items.map((i) => i.name),
                          if (meal.note.isNotEmpty) meal.note,
                        ].join(', '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall,
                      ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(left: 67, top: 2),
                child: Text('отмечено только время', style: t.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
