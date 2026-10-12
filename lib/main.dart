import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'screens/month_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/today_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru';
  await initializeDateFormatting('ru');
  final store = await AppStore.load();
  runApp(StoreScope(store: store, child: const MedLogApp()));
}

/// Gives any widget access to the store: `StoreScope.of(context)`.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class MedLogApp extends StatelessWidget {
  const MedLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedLog',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: IndexedStack(
              index: _tab,
              children: const [TodayScreen(), MonthScreen(), ScheduleScreen()],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: C.lineSoft, width: 1.2)),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.check_box_outlined),
              label: 'Сегодня',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              label: 'Месяц',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              label: 'Схема',
            ),
          ],
        ),
      ),
    );
  }
}
