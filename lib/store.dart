import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';
import 'debt_plan.dart';
import 'format.dart';
import 'models.dart';
import 'rates.dart';

/// ملخّص شهر واحد
class MonthStats {
  final DateTime month;
  final double income;
  final double baseIncome;
  final double extraIncome;
  final double invested;
  final double spent;
  final double essential;
  final double waste;
  final Map<String, double> byCategory;
  final int daysCounted;
  final int count;

  MonthStats({
    required this.month,
    required this.baseIncome,
    required this.extraIncome,
    required this.invested,
    required this.spent,
    required this.essential,
    required this.waste,
    required this.byCategory,
    required this.daysCounted,
    required this.count,
  }) : income = baseIncome + extraIncome;

  double get saved => income - spent;

  /// النقد المتبقي بعد المصاريف وشراء المدخرات
  double get cashLeft => income - spent - invested;
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
  static const _kExtra = 'extra_income_v1';
  static const _kCats = 'categories_v1';
  static const _kRates = 'rates_v1';
  static const _kDebts = 'debts_v1';
  static const _kDebtPay = 'debt_payments_v1';

  late SharedPreferences _prefs;

  List<Expense> expenses = [];
  List<WalletTx> wallet = [];

  /// دخل مخصّص لكل شهر (المفتاح yyyy-MM)
  Map<String, double> incomes = {};

  /// دخل إضافي (ثمن بيع دولار/ذهب أو دخل يدوي)
  List<IncomeEntry> extraIncome = [];
  List<Debt> debts = [];
  List<DebtPayment> debtPayments = [];

  // ---------------- أسعار السوق ----------------
  Rates? rates;
  bool ratesLoading = false;

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
    final r = _prefs.getString(_kRates);
    if (r != null) {
      try {
        rates = Rates.fromJson(jsonDecode(r) as Map<String, dynamic>);
      } catch (_) {}
    }
    refreshRates();
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
    final x = _prefs.getString(_kExtra);
    extraIncome = x == null
        ? []
        : (jsonDecode(x) as List)
            .map((e) => IncomeEntry.fromJson(e as Map<String, dynamic>))
            .toList();
    final dj = _prefs.getString(_kDebts);
    debts = dj == null
        ? []
        : (jsonDecode(dj) as List)
            .map((e) => Debt.fromJson(e as Map<String, dynamic>))
            .toList();
    final pj = _prefs.getString(_kDebtPay);
    debtPayments = pj == null
        ? []
        : (jsonDecode(pj) as List)
            .map((e) => DebtPayment.fromJson(e as Map<String, dynamic>))
            .toList();
    final cats = _prefs.getString(_kCats);
    customCategories = cats == null
        ? []
        : (jsonDecode(cats) as List)
            .map((e) => Category.fromJson(e as Map<String, dynamic>))
            .toList();
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

  Future<void> _saveExtra() async {
    await _prefs.setString(
        _kExtra, jsonEncode(extraIncome.map((e) => e.toJson()).toList()));
    _touch();
  }

  Future<void> _saveDebts() async {
    await _prefs.setString(
        _kDebts, jsonEncode(debts.map((e) => e.toJson()).toList()));
    await _prefs.setString(_kDebtPay,
        jsonEncode(debtPayments.map((e) => e.toJson()).toList()));
    _touch();
  }

  Future<void> _saveCats() async {
    await _prefs.setString(_kCats,
        jsonEncode(customCategories.map((e) => e.toJson()).toList()));
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
        'extraIncome': extraIncome.map((e) => e.toJson()).toList(),
        'categories': customCategories.map((e) => e.toJson()).toList(),
        'debts': debts.map((e) => e.toJson()).toList(),
        'debtPayments': debtPayments.map((e) => e.toJson()).toList(),
        'settings': _settingsJson,
      };

  Future<void> applySnapshot(Map<String, dynamic> d) async {
    await _prefs.setString(_kExpenses, jsonEncode(d['expenses'] ?? []));
    await _prefs.setString(_kWallet, jsonEncode(d['wallet'] ?? []));
    await _prefs.setString(_kIncomes, jsonEncode(d['incomes'] ?? {}));
    await _prefs.setString(_kExtra, jsonEncode(d['extraIncome'] ?? []));
    await _prefs.setString(_kCats, jsonEncode(d['categories'] ?? []));
    await _prefs.setString(_kDebts, jsonEncode(d['debts'] ?? []));
    await _prefs.setString(_kDebtPay, jsonEncode(d['debtPayments'] ?? []));
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
  /// رصيد الدولار
  double get walletBalance => holding(Asset.usd);

  double holding(Asset a) => wallet
      .where((t) => t.asset == a.key)
      .fold(0.0, (s, t) => s + t.amount);

  void addWalletTx(WalletTx t) {
    wallet.add(t);
    _sort();
    _saveWallet();
    notifyListeners();
  }

  void deleteWalletTx(String id) {
    wallet.removeWhere((x) => x.id == id);
    _saveWallet();
    if (extraIncome.any((e) => e.txId == id)) {
      extraIncome.removeWhere((e) => e.txId == id);
      _saveExtra();
    }
    notifyListeners();
  }

  /// يعيد حركة محذوفة (مع دخل البيع المرتبط بها)
  void restoreWalletTx(WalletTx t, IncomeEntry? linked) {
    wallet.add(t);
    _sort();
    _saveWallet();
    if (linked != null) {
      extraIncome.add(linked);
      _saveExtra();
    }
    notifyListeners();
  }

  IncomeEntry? incomeForTx(String txId) {
    for (final e in extraIncome) {
      if (e.txId == txId) return e;
    }
    return null;
  }

  /// شراء أو بيع أصل بسعر محدد (بعملة المصاريف).
  /// عند البيع يُضاف الثمن للميزانية كدخل إضافي.
  void trade(Asset a,
      {required bool buy,
      required double qty,
      required double price,
      String note = ''}) {
    final id = newId();
    final total = qty * price;
    wallet.add(WalletTx(
      id: id,
      amount: buy ? qty : -qty,
      date: DateTime.now(),
      note: note,
      asset: a.key,
      price: price,
      total: total,
    ));
    _sort();
    _saveWallet();
    if (!buy) {
      extraIncome.add(IncomeEntry(
        id: '${id}_inc',
        amount: total,
        date: DateTime.now(),
        note: 'بيع ${a == Asset.usd ? '${_q(qty)} دولار' : '${_q(qty)} غ ${a.label}'}',
        txId: id,
      ));
      _saveExtra();
    }
    notifyListeners();
  }

  String _q(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  // ---------------- دخل إضافي ----------------
  void addExtraIncome(double amount, String note, DateTime date) {
    extraIncome.add(
        IncomeEntry(id: newId(), amount: amount, date: date, note: note));
    _saveExtra();
    notifyListeners();
  }

  void deleteExtraIncome(String id) {
    extraIncome.removeWhere((e) => e.id == id);
    _saveExtra();
    notifyListeners();
  }

  // ---------------- الديون ----------------
  /// سعر الدولار بعملة المصاريف (للتحويل)، null إن لم يتوفر
  double? get usdToLocal =>
      currency == '\$' ? 1 : marketPrice(Asset.usd, buy: true);

  double paidFor(String debtId) => debtPayments
      .where((p) => p.debtId == debtId)
      .fold<double>(0, (s, p) => s + p.amount);

  double remaining(Debt d) {
    final r = d.amount - paidFor(d.id);
    return r < 0 ? 0 : r;
  }

  List<Debt> get activeDebts => debts.where((d) => remaining(d) > 0.005).toList();

  /// قيمة مبلغ بعملة الدين محوّلاً لعملة المصاريف
  double? toLocal(Debt d, double v) {
    if (!d.usd || currency == '\$') return v;
    final r = usdToLocal;
    return r == null ? null : v * r;
  }

  /// مجموع الديون المتبقية بعملة المصاريف (null عند نقص سعر الصرف)
  double? get totalDebtLocal {
    double s = 0;
    for (final d in debts) {
      final v = toLocal(d, remaining(d));
      if (v == null) return null;
      s += v;
    }
    return s;
  }

  double? get totalDebtOriginalLocal {
    double s = 0;
    for (final d in debts) {
      final v = toLocal(d, d.amount);
      if (v == null) return null;
      s += v;
    }
    return s;
  }

  /// مجموع الأقساط الشهرية الدنيا للديون القائمة بعملة المصاريف
  double? get monthlyMinPaymentsLocal {
    double s = 0;
    for (final d in activeDebts) {
      final v = toLocal(d, d.minPayment);
      if (v == null) return null;
      s += v;
    }
    return s;
  }

  List<DebtPayment> paymentsFor(String debtId) =>
      debtPayments.where((p) => p.debtId == debtId).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  /// إضافة دين. addToBudget: إضافة المبلغ المستلَم لميزانية هذا الشهر
  void addDebt(Debt d, {bool addToBudget = false}) {
    debts.add(d);
    if (addToBudget) {
      final local = toLocal(d, d.amount);
      if (local != null) {
        extraIncome.add(IncomeEntry(
            id: '${d.id}_loan',
            amount: local,
            date: d.date,
            note: 'دين: ${d.name}'));
        _saveExtra();
      }
    }
    _saveDebts();
    notifyListeners();
  }

  void updateDebt(Debt d) {
    final i = debts.indexWhere((x) => x.id == d.id);
    if (i >= 0) debts[i] = d;
    _saveDebts();
    notifyListeners();
  }

  void deleteDebt(String id) {
    for (final p in debtPayments.where((p) => p.debtId == id).toList()) {
      _removePaymentLinks(p);
    }
    debtPayments.removeWhere((p) => p.debtId == id);
    debts.removeWhere((d) => d.id == id);
    extraIncome.removeWhere((e) => e.id == '${id}_loan');
    _saveExtra();
    _saveExpenses();
    _saveWallet();
    _saveDebts();
    notifyListeners();
  }

  /// تسجيل دفعة. source: budget (مصروف بفئة "سداد ديون")،
  /// wallet (من محفظة الدولار)، none (تسجيل فقط).
  /// localRate: سعر الدولار بعملة المصاريف عند الدفع من الميزانية لدين بالدولار.
  void payDebt(Debt d, double amount,
      {required String source, double? localRate}) {
    final id = newId();
    String? link;
    if (source == 'budget') {
      final local = d.usd && currency != '\$'
          ? (localRate == null ? null : amount * localRate)
          : amount;
      if (local != null) {
        link = '${id}_exp';
        expenses.add(Expense(
          id: link,
          amount: local,
          categoryId: 'debt',
          date: DateTime.now(),
          note: 'سداد: ${d.name}',
          essential: true,
        ));
        _sort();
        _saveExpenses();
      }
    } else if (source == 'wallet' && d.usd) {
      link = '${id}_w';
      wallet.add(WalletTx(
        id: link,
        amount: -amount,
        date: DateTime.now(),
        note: 'سداد دين: ${d.name}',
        asset: 'usd',
      ));
      _sort();
      _saveWallet();
    }
    debtPayments.add(DebtPayment(
      id: id,
      debtId: d.id,
      amount: amount,
      date: DateTime.now(),
      linkId: link,
      source: source,
    ));
    _saveDebts();
    notifyListeners();
  }

  void _removePaymentLinks(DebtPayment p) {
    if (p.linkId == null) return;
    expenses.removeWhere((e) => e.id == p.linkId);
    wallet.removeWhere((w) => w.id == p.linkId);
  }

  void deleteDebtPayment(String id) {
    final p = debtPayments.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    _removePaymentLinks(p);
    debtPayments.removeWhere((x) => x.id == id);
    _saveExpenses();
    _saveWallet();
    _saveDebts();
    notifyListeners();
  }

  /// يحوّل الديون القائمة لعملة المصاريف لاستخدامها في محاكاة الخطة
  List<PlanDebt>? planDebts() {
    final out = <PlanDebt>[];
    for (final d in activeDebts) {
      final b = toLocal(d, remaining(d));
      final m = toLocal(d, d.minPayment);
      if (b == null || m == null) return null;
      out.add(PlanDebt(d.id, d.name, b, d.rate, m));
    }
    return out;
  }

  /// متوسط الفائض الشهري (الدخل - المصاريف) لآخر 3 أشهر فيها بيانات
  double get avgMonthlySurplus {
    final ms = lastMonths(4).where((m) => m.count > 0).toList();
    if (ms.isEmpty) return 0;
    return ms.fold<double>(0, (s, m) => s + m.saved) / ms.length;
  }

  /// مبلغ إضافي مقترح للسداد: نصف الفائض الشهري المعتاد
  double get suggestedExtraPayment {
    final v = avgMonthlySurplus * 0.5;
    return v > 0 ? v : 0;
  }

  // ---------------- الفئات ----------------
  void addCategory(String name, int icon, int color, bool essential) {
    customCategories = [
      ...customCategories,
      Category('c${newId()}', name, kCategoryIcons[icon], kCategoryColors[color],
          essential,
          custom: true),
    ];
    _saveCats();
    notifyListeners();
  }

  /// يحذف الفئة وينقل مصاريفها إلى "أخرى"
  void deleteCategory(String id) {
    customCategories = customCategories.where((c) => c.id != id).toList();
    var moved = false;
    for (var i = 0; i < expenses.length; i++) {
      if (expenses[i].categoryId == id) {
        expenses[i] = expenses[i].copyWith(categoryId: 'other');
        moved = true;
      }
    }
    if (moved) _saveExpenses();
    _saveCats();
    notifyListeners();
  }

  int expenseCountFor(String catId) =>
      expenses.where((e) => e.categoryId == catId).length;

  // ---------------- الأسعار ----------------
  Future<void> refreshRates() async {
    if (ratesLoading) return;
    ratesLoading = true;
    notifyListeners();
    final r = await RatesService.fetch();
    if (r != null) {
      rates = r;
      await _prefs.setString(_kRates, jsonEncode(r.toJson()));
    }
    ratesLoading = false;
    notifyListeners();
  }

  bool get isSyp => currency == 'ل.س' || currency == 'ل.س ق';

  /// معامل التحويل من الليرة القديمة إلى عملة المصاريف
  double? get _fromOldSyp {
    if (currency == 'ل.س') return 0.01;
    if (currency == 'ل.س ق') return 1;
    if (currency == '\$' && rates != null) return 1 / rates!.usdBuy;
    return null;
  }

  /// سعر السوق للوحدة بعملة المصاريف.
  /// buy=true: السعر الذي تشتري به (مبيع الصرّاف)، false: الذي تبيع به (شراء الصرّاف)
  double? marketPrice(Asset a, {required bool buy}) {
    if (a == Asset.usd && currency == '\$') return 1;
    final r = rates;
    if (r == null) return null;
    final f = _fromOldSyp;
    if (f == null) return null;
    final old = switch (a) {
      Asset.usd => buy ? r.usdSell : r.usdBuy,
      Asset.gold21 => buy ? r.g21Sell : r.g21Buy,
      Asset.gold18 => buy ? r.g18Sell : r.g18Buy,
    };
    if (currency == '\$' && a != Asset.usd) return old / r.usdBuy;
    return old * f;
  }

  /// قيمة أصل حالياً بعملة المصاريف (بسعر البيع للصرّاف)
  double? holdingValue(Asset a) {
    final q = holding(a);
    if (q == 0) return 0;
    final p = marketPrice(a, buy: false);
    return p == null ? null : q * p;
  }

  /// مجموع قيمة المدخرات بعملة المصاريف (null إن لم تتوفر الأسعار)
  double? get totalSavingsValue {
    double sum = 0;
    for (final a in Asset.values) {
      final v = holdingValue(a);
      if (v == null) return null;
      sum += v;
    }
    return sum;
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
    extraIncome.clear();
    debts.clear();
    debtPayments.clear();
    customCategories = [];
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
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
    final extra = extraIncome
        .where((e) => inMonth(e.date))
        .fold<double>(0, (s, e) => s + e.amount);
    final invested = wallet
        .where((t) => t.isTrade && t.isBuy && inMonth(t.date))
        .fold<double>(0, (s, t) => s + t.total!);
    return MonthStats(
      month: month,
      baseIncome: incomeFor(month),
      extraIncome: extra,
      invested: invested,
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
