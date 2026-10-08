import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'format.dart';
import 'models.dart';

/// ملخّص شهر واحد
class MonthStats {
  final DateTime month;
  final double income;
  final double spent;
  final double essential;
  final double waste;
  final Map<String, double> byCategory;
  final int daysCounted;
  final int count;

  MonthStats({
    required this.month,
    required this.income,
    required this.spent,
    required this.essential,
    required this.waste,
    required this.byCategory,
    required this.daysCounted,
    required this.count,
  });

  double get saved => income - spent;
  double get savingsRate => income > 0 ? saved / income : 0;
  double get dailyAvg => daysCounted > 0 ? spent / daysCounted : 0;
  double get wasteRatio => spent > 0 ? waste / spent : 0;
  double get projected => dailyAvg * daysInMonth(month);

  /// نسبة الدخل التي تذهب للمصاريف
  double get consumptionRate => income > 0 ? spent / income : 0;
}

class AppStore extends ChangeNotifier {
  static const _kExpenses = 'expenses_v1';
  static const _kWallet = 'wallet_v1';
  static const _kSettings = 'settings_v1';
  static const _kIncomes = 'incomes_v1';

  late SharedPreferences _prefs;

  List<Expense> expenses = [];
  List<WalletTx> wallet = [];

  /// دخل مخصّص لكل شهر (المفتاح yyyy-MM)
  Map<String, double> incomes = {};

  // الإعدادات
  String currency = '\$';
  double defaultIncome = 0;
  double monthlyBudget = 0;
  double savingsGoal = 0;
  String goalName = 'صندوق الطوارئ';
  bool onboarded = false;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final e = _prefs.getString(_kExpenses);
    if (e != null) {
      expenses = (jsonDecode(e) as List)
          .map((x) => Expense.fromJson(x as Map<String, dynamic>))
          .toList();
    }
    final w = _prefs.getString(_kWallet);
    if (w != null) {
      wallet = (jsonDecode(w) as List)
          .map((x) => WalletTx.fromJson(x as Map<String, dynamic>))
          .toList();
    }
    final i = _prefs.getString(_kIncomes);
    if (i != null) {
      incomes = (jsonDecode(i) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    }
    final s = _prefs.getString(_kSettings);
    if (s != null) {
      final m = jsonDecode(s) as Map<String, dynamic>;
      currency = (m['currency'] ?? '\$') as String;
      defaultIncome = ((m['income'] ?? 0) as num).toDouble();
      monthlyBudget = ((m['budget'] ?? 0) as num).toDouble();
      savingsGoal = ((m['goal'] ?? 0) as num).toDouble();
      goalName = (m['goalName'] ?? 'صندوق الطوارئ') as String;
      onboarded = (m['onboarded'] ?? false) as bool;
    }
    _sort();
    notifyListeners();
  }

  void _sort() {
    expenses.sort((a, b) => b.date.compareTo(a.date));
    wallet.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveExpenses() => _prefs.setString(
      _kExpenses, jsonEncode(expenses.map((e) => e.toJson()).toList()));
  Future<void> _saveWallet() => _prefs.setString(
      _kWallet, jsonEncode(wallet.map((e) => e.toJson()).toList()));
  Future<void> _saveIncomes() => _prefs.setString(_kIncomes, jsonEncode(incomes));
  Future<void> _saveSettings() => _prefs.setString(
      _kSettings,
      jsonEncode({
        'currency': currency,
        'income': defaultIncome,
        'budget': monthlyBudget,
        'goal': savingsGoal,
        'goalName': goalName,
        'onboarded': onboarded,
      }));

  String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---------------- المصاريف ----------------
  void addExpense(Expense e) {
    expenses.add(e);
    _sort();
    _saveExpenses();
    notifyListeners();
  }

  void updateExpense(Expense e) {
    final i = expenses.indexWhere((x) => x.id == e.id);
    if (i >= 0) expenses[i] = e;
    _sort();
    _saveExpenses();
    notifyListeners();
  }

  void deleteExpense(String id) {
    expenses.removeWhere((x) => x.id == id);
    _saveExpenses();
    notifyListeners();
  }

  // ---------------- المحفظة ----------------
  double get walletBalance => wallet.fold(0.0, (s, t) => s + t.amount);

  void addWalletTx(WalletTx t) {
    wallet.add(t);
    _sort();
    _saveWallet();
    notifyListeners();
  }

  void deleteWalletTx(String id) {
    wallet.removeWhere((x) => x.id == id);
    _saveWallet();
    notifyListeners();
  }

  // ---------------- الدخل والإعدادات ----------------
  double incomeFor(DateTime month) =>
      incomes[monthKey(month)] ?? defaultIncome;

  bool hasCustomIncome(DateTime month) => incomes.containsKey(monthKey(month));

  void setIncomeFor(DateTime month, double v) {
    incomes[monthKey(month)] = v;
    _saveIncomes();
    notifyListeners();
  }

  void clearIncomeFor(DateTime month) {
    incomes.remove(monthKey(month));
    _saveIncomes();
    notifyListeners();
  }

  void updateSettings({
    String? currency,
    double? defaultIncome,
    double? monthlyBudget,
    double? savingsGoal,
    String? goalName,
    bool? onboarded,
  }) {
    if (currency != null) this.currency = currency;
    if (defaultIncome != null) this.defaultIncome = defaultIncome;
    if (monthlyBudget != null) this.monthlyBudget = monthlyBudget;
    if (savingsGoal != null) this.savingsGoal = savingsGoal;
    if (goalName != null) this.goalName = goalName;
    if (onboarded != null) this.onboarded = onboarded;
    _saveSettings();
    notifyListeners();
  }

  Future<void> resetAll() async {
    expenses.clear();
    wallet.clear();
    incomes.clear();
    await _prefs.clear();
    currency = '\$';
    defaultIncome = 0;
    monthlyBudget = 0;
    savingsGoal = 0;
    goalName = 'صندوق الطوارئ';
    onboarded = false;
    notifyListeners();
  }

  // ---------------- الأشهر ----------------
  void selectMonth(DateTime m) {
    selectedMonth = DateTime(m.year, m.month);
    notifyListeners();
  }

  void shiftMonth(int delta) =>
      selectMonth(DateTime(selectedMonth.year, selectedMonth.month + delta));

  bool get isCurrentMonth {
    final n = DateTime.now();
    return selectedMonth.year == n.year && selectedMonth.month == n.month;
  }

  List<Expense> expensesIn(DateTime month) => expenses
      .where((e) => e.date.year == month.year && e.date.month == month.month)
      .toList();

  MonthStats statsFor(DateTime month) {
    final list = expensesIn(month);
    double spent = 0, ess = 0, waste = 0;
    final byCat = <String, double>{};
    for (final e in list) {
      spent += e.amount;
      if (e.essential) {
        ess += e.amount;
      } else {
        waste += e.amount;
      }
      byCat[e.categoryId] = (byCat[e.categoryId] ?? 0) + e.amount;
    }
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    final isFuture = DateTime(month.year, month.month)
        .isAfter(DateTime(now.year, now.month));
    final days = isFuture ? 0 : (isCurrent ? now.day : daysInMonth(month));
    return MonthStats(
      month: month,
      income: incomeFor(month),
      spent: spent,
      essential: ess,
      waste: waste,
      byCategory: byCat,
      daysCounted: days,
      count: list.length,
    );
  }

  MonthStats get current => statsFor(selectedMonth);

  MonthStats get previous => statsFor(
      DateTime(selectedMonth.year, selectedMonth.month - 1));

  /// آخر n أشهر (من الأقدم إلى الأحدث) حتى الشهر المختار
  List<MonthStats> lastMonths(int n) => List.generate(
      n,
      (i) => statsFor(DateTime(
          selectedMonth.year, selectedMonth.month - (n - 1 - i))));

  /// متوسط المصاريف الشهرية للأشهر التي فيها بيانات
  double get avgMonthlySpend {
    final months = <String, double>{};
    for (final e in expenses) {
      final k = monthKey(e.date);
      months[k] = (months[k] ?? 0) + e.amount;
    }
    if (months.isEmpty) return 0;
    return months.values.reduce((a, b) => a + b) / months.length;
  }
}
