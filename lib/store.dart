import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';
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

enum SyncState { off, syncing, ok, error }

class AppStore extends ChangeNotifier {
  static const _kExpenses = 'expenses_v1';
  static const _kWallet = 'wallet_v1';
  static const _kSettings = 'settings_v1';
  static const _kIncomes = 'incomes_v1';
  static const _kCloud = 'cloud_v1';
  static const _kUpdated = 'updated_at_v1';

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

  /// آخر وقت تعديل للبيانات المحلية
  DateTime updatedAt = DateTime(2000);

  // ---------------- قاعدة البيانات السحابية ----------------
  CloudConfig? cloud;
  CloudDb? _db;
  SyncState syncState = SyncState.off;
  String? syncError;
  DateTime? lastSync;
  Timer? _debounce;
  bool _pushing = false;
  bool _dirty = false;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _readLocal();
    final c = _prefs.getString(_kCloud);
    if (c != null) {
      cloud = CloudConfig.fromJson(jsonDecode(c) as Map<String, dynamic>);
      _db = CloudDb(cloud!);
      syncState = SyncState.syncing;
      // لا ننتظر الشبكة لفتح التطبيق
      syncNow();
    }
    notifyListeners();
  }

  void _readLocal() {
    expenses = [];
    wallet = [];
    incomes = {};
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
    if (s != null) _applySettings(jsonDecode(s) as Map<String, dynamic>);
    updatedAt =
        DateTime.tryParse(_prefs.getString(_kUpdated) ?? '') ?? DateTime(2000);
    _sort();
  }

  void _applySettings(Map<String, dynamic> m) {
    currency = (m['currency'] ?? '\$') as String;
    defaultIncome = ((m['income'] ?? 0) as num).toDouble();
    monthlyBudget = ((m['budget'] ?? 0) as num).toDouble();
    savingsGoal = ((m['goal'] ?? 0) as num).toDouble();
    goalName = (m['goalName'] ?? 'صندوق الطوارئ') as String;
    onboarded = (m['onboarded'] ?? false) as bool;
  }

  Map<String, dynamic> get _settingsJson => {
        'currency': currency,
        'income': defaultIncome,
        'budget': monthlyBudget,
        'goal': savingsGoal,
        'goalName': goalName,
        'onboarded': onboarded,
      };

  void _sort() {
    expenses.sort((a, b) => b.date.compareTo(a.date));
    wallet.sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> _saveExpenses() async {
    await _prefs.setString(
        _kExpenses, jsonEncode(expenses.map((e) => e.toJson()).toList()));
    _touch();
  }

  Future<void> _saveWallet() async {
    await _prefs.setString(
        _kWallet, jsonEncode(wallet.map((e) => e.toJson()).toList()));
    _touch();
  }

  Future<void> _saveIncomes() async {
    await _prefs.setString(_kIncomes, jsonEncode(incomes));
    _touch();
  }

  Future<void> _saveSettings() async {
    await _prefs.setString(_kSettings, jsonEncode(_settingsJson));
    _touch();
  }

  /// يسجّل وقت التعديل ويجدول رفعاً للسحابة بعد ثانيتين
  void _touch() {
    updatedAt = DateTime.now();
    _prefs.setString(_kUpdated, updatedAt.toIso8601String());
    if (_db == null) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), _push);
  }

  // ---------------- النسخة الكاملة ----------------
  Map<String, dynamic> toSnapshot() => {
        'v': 1,
        'updatedAt': updatedAt.toIso8601String(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'wallet': wallet.map((e) => e.toJson()).toList(),
        'incomes': incomes,
        'settings': _settingsJson,
      };

  Future<void> applySnapshot(Map<String, dynamic> d) async {
    await _prefs.setString(_kExpenses, jsonEncode(d['expenses'] ?? []));
    await _prefs.setString(_kWallet, jsonEncode(d['wallet'] ?? []));
    await _prefs.setString(_kIncomes, jsonEncode(d['incomes'] ?? {}));
    await _prefs.setString(_kSettings, jsonEncode(d['settings'] ?? {}));
    await _prefs.setString(
        _kUpdated, (d['updatedAt'] ?? DateTime.now().toIso8601String()) as String);
    _readLocal();
    notifyListeners();
  }

  /// نسخة احتياطية نصية (للنسخ/اللصق)
  String exportBackup() => jsonEncode(toSnapshot());

  Future<void> importBackup(String raw) async {
    final d = jsonDecode(raw.trim()) as Map<String, dynamic>;
    if (d['expenses'] is! List) throw const FormatException();
    d['updatedAt'] = DateTime.now().toIso8601String();
    await applySnapshot(d);
    _touch();
  }

  // ---------------- المزامنة ----------------
  bool get cloudEnabled => _db != null;

  Future<void> _push() async {
    if (_db == null || _pushing) return;
    _pushing = true;
    _dirty = false;
    syncState = SyncState.syncing;
    notifyListeners();
    try {
      await _db!.push(toSnapshot());
      syncState = SyncState.ok;
      syncError = null;
      lastSync = DateTime.now();
    } catch (e) {
      syncState = SyncState.error;
      syncError = e is CloudException ? e.message : 'تعذّر الاتصال بالإنترنت';
      _dirty = true;
    } finally {
      _pushing = false;
      notifyListeners();
    }
    if (_dirty && syncState == SyncState.ok) _push();
  }

  /// يقارن النسختين: الأحدث يفوز
  Future<void> syncNow() async {
    if (_db == null) return;
    syncState = SyncState.syncing;
    notifyListeners();
    try {
      final remote = await _db!.pull();
      if (remote != null && remote.updatedAt.isAfter(updatedAt)) {
        await applySnapshot(remote.data);
        syncState = SyncState.ok;
      } else if (remote == null || updatedAt.isAfter(remote.updatedAt)) {
        if (cloud!.token.isNotEmpty) {
          await _db!.push(toSnapshot());
        }
        syncState = SyncState.ok;
      } else {
        syncState = SyncState.ok;
      }
      syncError = null;
      lastSync = DateTime.now();
    } catch (e) {
      syncState = SyncState.error;
      syncError = e is CloudException ? e.message : 'تعذّر الاتصال بالإنترنت';
    }
    notifyListeners();
  }

  /// ربط قاعدة البيانات. إن وُجدت نسخة سحابية تُستعاد، وإلا تُرفع البيانات الحالية.
  Future<bool> connectCloud(CloudConfig c) async {
    final db = CloudDb(c);
    final remote = await db.pull(); // يرمي خطأ عند كلمة سر خاطئة
    if (remote == null && c.token.isEmpty) {
      throw CloudException(
          'لا توجد بيانات محفوظة في قاعدة البيانات بعد. أدخل رمز الوصول لبدء الحفظ');
    }
    var restored = false;
    if (remote != null &&
        (remote.updatedAt.isAfter(updatedAt) || expenses.isEmpty)) {
      await applySnapshot(remote.data);
      restored = true;
    } else {
      await db.push(toSnapshot());
    }
    // نحفظ الإعدادات فقط بعد نجاح الاتصال
    cloud = c;
    _db = db;
    await _prefs.setString(_kCloud, jsonEncode(c.toJson()));
    syncState = SyncState.ok;
    syncError = null;
    lastSync = DateTime.now();
    notifyListeners();
    return restored;
  }

  Future<void> disconnectCloud() async {
    _debounce?.cancel();
    cloud = null;
    _db = null;
    syncState = SyncState.off;
    syncError = null;
    await _prefs.remove(_kCloud);
    notifyListeners();
  }

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
    final c = _prefs.getString(_kCloud);
    await _prefs.clear();
    if (c != null) await _prefs.setString(_kCloud, c);
    currency = '\$';
    defaultIncome = 0;
    monthlyBudget = 0;
    savingsGoal = 0;
    goalName = 'صندوق الطوارئ';
    onboarded = false;
    _touch(); // تُمسح النسخة السحابية أيضاً
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
