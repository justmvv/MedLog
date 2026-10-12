import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../theme.dart';
import '../widgets.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Refresh the "overdue" state and the day change.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = DateTime.now();
    final slots = store.slotsFor(now);
    final taken = slots.where((s) => s.taken).length;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE').format(now).toUpperCase(),
                      style: t.labelSmall,
                    ),
                    Text(
                      DateFormat('d MMMM').format(now),
                      style: t.headlineMedium,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: AppLogo(size: 40),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (slots.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  '$taken из ${slots.length}',
                  style: t.titleMedium?.copyWith(color: C.accent),
                ),
                const SizedBox(width: 6),
                Text('приёмов', style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 6),
            HatchProgress(value: taken / slots.length),
          ],
          const SectionLabel('Лекарства'),
          if (slots.isEmpty)
            const HatchEmpty(
              text:
                  'На сегодня приёмов нет.\nДобавьте лекарства во вкладке «Схема».',
            )
          else
            for (final s in slots) DoseTile(slot: s),
        ],
      ),
    );
  }
}
