import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';

Meal quickMeal() => Meal(id: AppStore.newId(), at: DateTime.now(), items: []);

Future<void> openMealEditor(BuildContext context, {Meal? meal, DateTime? day}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => MealEditor(meal: meal, day: day),
    ),
  );
}

class MealEditor extends StatefulWidget {
  const MealEditor({super.key, this.meal, this.day});
  final Meal? meal;
  final DateTime? day;

  @override
  State<MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<MealEditor> {
  late DateTime _at;
  late final List<MealItem> _items;
  late final TextEditingController _note;
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    final m = widget.meal;
    final now = DateTime.now();
    final d = widget.day;
    _at =
        m?.at ??
        (d == null || dayOf(d) == dayOf(now)
            ? now
            : DateTime(d.year, d.month, d.day, 13));
    _items = [
      for (final i in m?.items ?? <MealItem>[])
        MealItem(name: i.name, grams: i.grams, kcal100: i.kcal100),
    ];
    _note = TextEditingController(text: m?.note ?? '');
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _note.dispose();
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  int get _kcal => _items.fold(0, (s, i) => s + i.kcal);

  void _add(Food f) {
    setState(() {
      _items.add(MealItem(name: f.name, grams: f.portion, kcal100: f.kcal100));
      _search.clear();
    });
  }

  Future<void> _pickTime() async {
    final p = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at),
    );
    if (p != null) {
      setState(
        () => _at = DateTime(_at.year, _at.month, _at.day, p.hour, p.minute),
      );
    }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _at,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (p != null) {
      setState(
        () => _at = DateTime(p.year, p.month, p.day, _at.hour, _at.minute),
      );
    }
  }

  Future<void> _newFood(String name) async {
    final store = StoreScope.of(context);
    final nameC = TextEditingController(text: name);
    final kcalC = TextEditingController();
    final portionC = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый продукт'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kcalC,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'ккал на 100 г'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: portionC,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Обычная порция, г'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    final kcal = int.tryParse(kcalC.text);
    if (ok != true || kcal == null || nameC.text.trim().isEmpty) return;
    final f = Food(
      nameC.text.trim(),
      kcal,
      int.tryParse(portionC.text) ?? 100,
      'Мои продукты',
      custom: true,
    );
    store.addCustomFood(f);
    _add(f);
  }

  void _save() {
    final store = StoreScope.of(context);
    store.upsertMeal(
      Meal(
        id: widget.meal?.id ?? AppStore.newId(),
        at: _at,
        items: _items.where((i) => i.grams > 0).toList(),
        note: _note.text.trim(),
      ),
    );
    Navigator.pop(context);
  }

  void _delete() {
    StoreScope.of(context).deleteMeal(widget.meal!);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final t = Theme.of(context).textTheme;
    final q = _search.text;
    final results = q.isEmpty
        ? const <Food>[]
        : store.searchFoods(q).take(30).toList();
    final frequent = store.frequentFoods;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.meal == null ? 'Еда' : 'Изменить приём пищи'),
        actions: [
          if (widget.meal != null)
            IconButton(
              tooltip: 'Удалить',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: _save,
              child: const Text('Сохранить'),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(
                      DateFormat.Hm().format(_at),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _pickDate,
                    child: Text(DateFormat('d MMMM').format(_at)),
                  ),
                  const Spacer(),
                  Text(
                    '$_kcal',
                    style: t.headlineMedium?.copyWith(color: C.accent),
                  ),
                  const SizedBox(width: 4),
                  Text('ккал', style: t.bodySmall),
                ],
              ),
              const SectionLabel('Состав'),
              if (_items.isEmpty)
                const HatchEmpty(
                  text: 'Можно сохранить только время,\nили найти блюда ниже',
                ),
              for (var i = 0; i < _items.length; i++) _itemRow(i),
              const SizedBox(height: 14),
              TextField(
                controller: _search,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: 'Поиск в справочнике калорий',
                  prefixIcon: const Icon(Icons.search, color: C.inkSoft),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _search.clear,
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (q.isEmpty && frequent.isNotEmpty) ...[
                Text('Часто', style: t.labelSmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final f in frequent)
                      ActionChip(
                        label: Text(f.name),
                        side: const BorderSide(color: C.line),
                        backgroundColor: C.paper,
                        onPressed: () => _add(f),
                      ),
                  ],
                ),
              ],
              for (final f in results)
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(f.name),
                  subtitle: Text('${f.category} · порция ${f.portion} г'),
                  trailing: Text(
                    '${f.kcal100} ккал/100 г',
                    style: t.bodySmall?.copyWith(color: C.accent),
                  ),
                  onTap: () => _add(f),
                ),
              if (q.trim().isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _newFood(q.trim()),
                    icon: const Icon(Icons.add),
                    label: Text('Добавить «${q.trim()}» в справочник'),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Заметка'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemRow(int idx) {
    final it = _items[idx];
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: C.paper,
        border: Border.all(color: C.line, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(child: Text(it.name, style: t.bodyMedium)),
          SizedBox(
            width: 70,
            child: TextFormField(
              key: ObjectKey(it),
              initialValue: '${it.grams}',
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(suffixText: 'г'),
              onChanged: (v) => setState(() => it.grams = int.tryParse(v) ?? 0),
            ),
          ),
          SizedBox(
            width: 76,
            child: Text(
              '${it.kcal} ккал',
              textAlign: TextAlign.right,
              style: t.bodySmall?.copyWith(color: C.accent),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: C.inkSoft),
            onPressed: () => setState(() => _items.removeAt(idx)),
          ),
        ],
      ),
    );
  }
}
