import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'screens/add_expense.dart';
import 'screens/dashboard.dart';
import 'screens/expenses.dart';
import 'screens/settings.dart';
import 'screens/tips.dart';
import 'screens/wallet.dart';
import 'screens/waste.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  final store = AppStore();
  await store.load();
  runApp(ChangeNotifierProvider.value(value: store, child: const MasrofiApp()));
}

class MasrofiApp extends StatelessWidget {
  const MasrofiApp({super.key});

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<AppStore, bool>((s) => s.onboarded);
    return MaterialApp(
      title: 'مصروفي',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: onboarded ? const HomeShell() : const OnboardingScreen(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int i) {
    HapticFeedback.selectionClick();
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(goTo: _go),
      const ExpensesScreen(),
      const WasteScreen(),
      const WalletScreen(),
      const TipsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index <= 2
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.lightImpact();
                openExpenseSheet(context);
              },
              backgroundColor: AppColors.primary,
              foregroundColor: const Color(0xFF04140E),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('مصروف',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'الرئيسية'),
          NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'المصاريف'),
          NavigationDestination(
              icon: Icon(Icons.local_fire_department_outlined),
              selectedIcon: Icon(Icons.local_fire_department_rounded),
              label: 'الهدر'),
          NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings_rounded),
              label: 'المدخرات'),
          NavigationDestination(
              icon: Icon(Icons.lightbulb_outline_rounded),
              selectedIcon: Icon(Icons.lightbulb_rounded),
              label: 'اقتراحات'),
        ],
      ),
    );
  }
}
