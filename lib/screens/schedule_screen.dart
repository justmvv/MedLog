import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

/// Идентификатор сборки, задаётся в tool/build_web.sh.
const buildId = String.fromEnvironment('BUILD_ID', defaultValue: 'dev');

/// Схема приёма: список лекарств с примерным временем.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final active = store.activeMeds;
    final today = dayOf(DateTime.now());
    final past =
        store.meds
            .where((m) => m.endDate != null && !m.activeOn(today))
            .toList()
          ..sort((a, b) => b.endDate!.compareTo(a.endDate!));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Лекарство'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: Text('Схема приёма', style: t.headlineMedium)),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: AppLogo(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Время указывается примерно — отметка ставится фактическая.',
            style: t.bodySmall,
          ),
          const SectionLabel('Сейчас принимаю'),
          if (active.isEmpty)
            HatchEmpty(
              text: 'Пока пусто',
              action: OutlinedButton.icon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Добавить лекарство'),
              ),
            ),
          for (final m in active)
            _MedCard(med: m, onTap: () => _edit(context, m)),
          if (past.isNotEmpty) ...[
            const SectionLabel('Завершённые'),
            for (final m in past)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  m.name,
                  style: const TextStyle(
                    color: C.inkSoft,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '${DateFormat('d MMM y').format(m.startDate)} — '
                  '${DateFormat('d MMM y').format(m.endDate!)} · '
                  '${m.times.map(hhmm).join(', ')}',
                ),
              ),
          ],
          const SizedBox(height: 32),
          Text(
            'Крест · сборка $buildId',
            textAlign: TextAlign.center,
            style: t.labelSmall,
          ),
        ],
      ),
    );
  }

  void _edit(BuildContext context, Medication? med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StoreScope(
        store: StoreScope.of(context),
        child: MedEditor(med: med),
      ),
    );
  }
}

class _MedCard extends StatelessWidget {
  const _MedCard({required this.med, required this.onTap});
  final Medication med;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.paper,
          border: Border.all(color: C.line, width: 1.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(width: 3, height: 40, color: C.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(med.name, style: t.titleMedium),
                  if (med.dose.isNotEmpty || med.note.isNotEmpty)
                    Text(
                      [
                        med.dose,
                        med.note,
                      ].where((e) => e.isNotEmpty).join(' · '),
                      style: t.bodySmall,
                    ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [for (final tm in med.times) _TimeTag(hhmm(tm))],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: C.inkSoft),
          ],
        ),
      ),
    );
  }
}

class _TimeTag extends StatelessWidget {
  const _TimeTag(this.text, {this.onDelete});
  final String text;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(8, 3, onDelete == null ? 8 : 2, 3),
      decoration: BoxDecoration(
        border: Border.all(color: C.soft, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '≈ $text',
            style: const TextStyle(color: C.accent, fontSize: 13),
          ),
          if (onDelete != null)
            InkWell(
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.close, size: 14, color: C.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

class MedEditor extends StatefulWidget {
  const MedEditor({super.key, this.med});
  final Medication? med;

  @override
  State<MedEditor> createState() => _MedEditorState();
}

class _MedEditorState extends State<MedEditor> {
  late final _name = TextEditingController(text: widget.med?.name ?? '');
  late final _dose = TextEditingController(text: widget.med?.dose ?? '');
  late final _note = TextEditingController(text: widget.med?.note ?? '');
  late List<int> _times = [...?widget.med?.times];

  static const _presets = {
    '1 раз': [9 * 60],
    '2 раза': [9 * 60, 21 * 60],
    '3 раза': [8 * 60, 14 * 60, 20 * 60],
  };

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _addTime() async {
    final p = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Примерное время приёма',
    );
    if (p == null) return;
    final m = p.hour * 60 + p.minute;
    if (!_times.contains(m)) setState(() => _times = [..._times, m]..sort());
  }

  bool get _valid => _name.text.trim().isNotEmpty && _times.isNotEmpty;

  void _save() {
    final store = StoreScope.of(context);
    final med =
        widget.med ??
        Medication(
          id: AppStore.newId(),
          name: '',
          dose: '',
          times: const [],
          startDate: dayOf(DateTime.now()),
        );
    store.saveMed(
      med,
      name: _name.text.trim(),
      dose: _dose.text.trim(),
      note: _note.text.trim(),
      times: _times,
    );
    Navigator.pop(context);
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Завершить приём?'),
        content: const Text(
          'Лекарство исчезнет из ежедневного списка. История прошлых дней сохранится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      StoreScope.of(context).stopMed(widget.med!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.med == null ? 'Новое лекарство' : 'Лекарство',
                    style: t.titleLarge,
                  ),
                ),
                if (widget.med != null)
                  TextButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Завершить'),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: widget.med == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _dose,
                    decoration: const InputDecoration(
                      labelText: 'Доза',
                      hintText: '1 таб., 500 мг',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _note,
                    decoration: const InputDecoration(
                      labelText: 'Заметка',
                      hintText: 'после еды',
                    ),
                  ),
                ),
              ],
            ),
            const SectionLabel('Время приёма'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _presets.entries)
                  ActionChip(
                    label: Text(e.key),
                    side: const BorderSide(color: C.line),
                    backgroundColor: C.paper,
                    onPressed: () => setState(() => _times = [...e.value]),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tm in _times)
                  _TimeTag(
                    hhmm(tm),
                    onDelete: () =>
                        setState(() => _times = [..._times]..remove(tm)),
                  ),
                OutlinedButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('время'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _valid ? _save : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Сохранить'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
