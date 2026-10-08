import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../debt_plan.dart';
import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

String _amt(AppStore s, Debt d, double v, {bool dec = false}) =>
    d.usd ? money(v, '\$', decimals: dec) : money(v, s.currency, decimals: dec);

String _monthsLabel(int m) {
  if (m <= 0) return 'الآن';
  if (m == 1) return 'شهر واحد';
  if (m == 2) return 'شهران';
  if (m <= 10) return '$m أشهر';
  if (m < 24) return '$m شهراً';
  final y = m ~/ 12, r = m % 12;
  final ys = y == 1 ? 'سنة' : (y == 2 ? 'سنتان' : '$y سنوات');
  return r == 0 ? ys : '$ys و$r ${r <= 10 ? 'أشهر' : 'شهراً'}';
}

String _inMonths(int m) {
  final n = DateTime.now();
  return monthName(DateTime(n.year, n.month + m));
}

class DebtsScreen extends StatefulWidget {
  final int initialTab;
  const DebtsScreen({super.key, this.initialTab = 0});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  late int _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Scaffold(
      appBar: AppBar(title: const Text('الديون')),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => openDebtForm(context),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              icon: const Icon(Icons.add_rounded),
              label: const Text('دين جديد',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          _Summary(store: s),
          const SizedBox(height: 14),
          _Seg(
            index: _tab,
            labels: const ['ديوني', 'خطة السداد', 'لا للاستدانة'],
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 6),
          if (_tab == 0) _DebtList(store: s),
          if (_tab == 1) _PlanView(store: s),
          if (_tab == 2) _NoDebtView(store: s),
        ],
      ),
    );
  }
}

// ---------------- الملخّص ----------------
class _Summary extends StatelessWidget {
  final AppStore store;
  const _Summary({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final total = s.totalDebtLocal;
    final orig = s.totalDebtOriginalLocal;
    final cur = s.currency;
    final paidRatio =
        (total != null && orig != null && orig > 0) ? 1 - total / orig : 0.0;
    final mins = s.monthlyMinPaymentsLocal;
    final plan = s.planDebts();
    final r = plan == null
        ? null
        : simulatePlan(plan, s.suggestedExtraPayment, DebtStrategy.avalanche);
    final usdDebts = s.activeDebts.where((d) => d.usd).toList();

    return AppCard(
      padding: const EdgeInsets.all(22),
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [Color(0xFF7F1D1D), Color(0xFF4C1D3D), Color(0xFF1E1B3A)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('إجمالي الديون المتبقية',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
                total == null
                    ? '—'
                    : (s.debts.isEmpty
                        ? 'لا ديون 🎉'
                        : money(total, cur, decimals: false)),
                style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
          if (total == null)
            Text('تعذّر تحويل الديون بالدولار: لا يوجد سعر صرف حالياً',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          if (usdDebts.isNotEmpty && cur != '\$' && total != null)
            Text(
                'منها ${usd(usdDebts.fold<double>(0, (a, d) => a + s.remaining(d)))} بالدولار محسوبة بسعر اليوم',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
          if (s.debts.isNotEmpty) ...[
            const SizedBox(height: 16),
            ProgressBar(
                value: paidRatio,
                color: const Color(0xFF86EFAC),
                height: 8),
            const SizedBox(height: 8),
            Text('سدّدت ${pct(paidRatio)} من ديونك',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
            const SizedBox(height: 14),
            Row(children: [
              _item('الأقساط الشهرية',
                  mins == null ? '—' : money(mins, cur, decimals: false)),
              _item(
                  'التحرر من الديون',
                  r == null || !r.feasible || r.months == 0
                      ? (s.activeDebts.isEmpty ? 'تمّ ✓' : 'حدّد خطة')
                      : _inMonths(r.months)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _item(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ],
        ),
      );
}

class _Seg extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _Seg(
      {required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: i == index ? AppColors.surface2 : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: i == index ? AppColors.text : AppColors.muted,
                    )),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------- قائمة الديون ----------------
class _DebtList extends StatelessWidget {
  final AppStore store;
  const _DebtList({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    if (s.debts.isEmpty) {
      return const EmptyState(
        icon: Icons.handshake_rounded,
        title: 'لا توجد ديون مسجّلة',
        subtitle:
            'سجّل أي مبلغ تدين به (بالليرة أو بالدولار) لتتابع سداده وتحصل على خطة للتخلص منه',
      );
    }
    final list = [...s.debts]..sort((a, b) {
        final ra = s.remaining(a) > 0.005, rb = s.remaining(b) > 0.005;
        if (ra != rb) return ra ? -1 : 1;
        return b.date.compareTo(a.date);
      });
    return Column(children: [
      const SizedBox(height: 10),
      for (final d in list)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DebtCard(debt: d, store: s),
        ),
    ]);
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final AppStore store;
  const _DebtCard({required this.debt, required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store, d = debt;
    final rem = s.remaining(d);
    final done = rem <= 0.005;
    final ratio = d.amount > 0 ? 1 - rem / d.amount : 1.0;
    final now = DateTime.now();
    final overdue = !done &&
        d.due != null &&
        DateTime(d.due!.year, d.due!.month, d.due!.day)
            .isBefore(DateTime(now.year, now.month, now.day));
    return AppCard(
      onTap: () => openDebtDetails(context, d),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (done ? AppColors.primary : AppColors.danger)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                  done ? Icons.check_circle_rounded : Icons.request_quote_rounded,
                  color: done ? AppColors.primary : AppColors.danger,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15.5)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Pill(d.usd ? 'دولار' : s.currency, AppColors.info),
                    if (d.rate > 0)
                      Pill('فائدة ${d.rate.toStringAsFixed(d.rate % 1 == 0 ? 0 : 1)}%',
                          AppColors.warning),
                    if (overdue) const Pill('متأخر', AppColors.danger),
                    if (done) const Pill('مسدّد', AppColors.primary),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_amt(s, d, rem),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: done ? AppColors.primary : AppColors.text)),
                Text('من ${_amt(s, d, d.amount)}',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          ProgressBar(
              value: ratio,
              color: done ? AppColors.primary : AppColors.warning,
              height: 7),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                [
                  if (d.minPayment > 0) 'القسط: ${_amt(s, d, d.minPayment)}',
                  if (d.due != null)
                    'الاستحقاق: ${d.due!.day} ${monthName(d.due!)}',
                  if (d.minPayment <= 0 && d.due == null) 'بدون قسط محدد',
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
            if (!done)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => openPaySheet(context, d),
                child: const Text('تسديد'),
              ),
          ]),
        ],
      ),
    );
  }
}

// ---------------- إضافة/تعديل دين ----------------
Future<void> openDebtForm(BuildContext context, {Debt? existing}) =>
    showAppSheet(context, _DebtForm(existing: existing));

class _DebtForm extends StatefulWidget {
  final Debt? existing;
  const _DebtForm({this.existing});

  @override
  State<_DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<_DebtForm> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _rate;
  late final TextEditingController _min;
  late bool _usd;
  DateTime? _due;
  bool _toBudget = false;

  String _f(double v) => v == 0 ? '' : (v % 1 == 0 ? v.toStringAsFixed(0) : '$v');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _amount = TextEditingController(text: e == null ? '' : _f(e.amount));
    _rate = TextEditingController(text: e == null ? '' : _f(e.rate));
    _min = TextEditingController(text: e == null ? '' : _f(e.minPayment));
    _usd = e?.usd ?? false;
    _due = e?.due;
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _rate.dispose();
    _min.dispose();
    super.dispose();
  }

  void _save() {
    final s = context.read<AppStore>();
    final name = _name.text.trim();
    final amount = parseAmount(_amount.text) ?? 0;
    if (name.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('أدخل اسم الدائن والمبلغ')));
      return;
    }
    final rate = parseAmount(_rate.text) ?? 0;
    final min = parseAmount(_min.text) ?? 0;
    final e = widget.existing;
    if (e == null) {
      s.addDebt(
        Debt(
          id: s.newId(),
          name: name,
          usd: _usd,
          amount: amount,
          rate: rate,
          minPayment: min,
          date: DateTime.now(),
          due: _due,
        ),
        addToBudget: _toBudget,
      );
    } else {
      s.updateDebt(e.copyWith(
        name: name,
        amount: amount,
        rate: rate,
        minPayment: min,
        due: _due,
        clearDue: _due == null,
      ));
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final editing = widget.existing != null;
    final unit = _usd ? 'USD' : s.currency;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(editing ? 'تعديل الدين' : 'دين جديد',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(
              labelText: 'لمن الدين؟', hintText: 'مثال: أخي، قرض البنك، المحل'),
        ),
        const SizedBox(height: 12),
        if (!editing && s.currency != '\$') ...[
          const Text('عملة الدين',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _curBtn(s.currency, !_usd, () => setState(() => _usd = false))),
            const SizedBox(width: 8),
            Expanded(child: _curBtn('دولار \$', _usd, () => setState(() => _usd = true))),
          ]),
          const SizedBox(height: 12),
        ],
        AmountField(
            controller: _amount,
            label: editing ? 'أصل الدين' : 'المبلغ المتبقي عليك',
            suffix: unit,
            autofocus: !editing),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: AmountField(
                controller: _min, label: 'القسط الشهري', suffix: unit),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AmountField(
                controller: _rate, label: 'الفائدة السنوية', suffix: '%'),
          ),
        ]),
        const Padding(
          padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Text('اترك القسط أو الفائدة فارغاً إن لم يوجد (مثل دين لصديق).',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: _due ?? DateTime(now.year, now.month + 1, now.day),
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 30),
            );
            if (d != null) setState(() => _due = d);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const Icon(Icons.event_rounded, color: AppColors.muted, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    _due == null
                        ? 'موعد السداد النهائي (اختياري)'
                        : 'موعد السداد: ${_due!.day} ${monthName(_due!)}',
                    style: TextStyle(
                        color: _due == null ? AppColors.muted : AppColors.text)),
              ),
              if (_due != null)
                GestureDetector(
                  onTap: () => setState(() => _due = null),
                  child: const Icon(Icons.close_rounded,
                      color: AppColors.muted, size: 20),
                ),
            ]),
          ),
        ),
        if (!editing) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: _toBudget,
            onChanged: (v) => setState(() => _toBudget = v),
            title: const Text('استلمت المبلغ الآن',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
            subtitle: const Text('يُضاف لميزانية هذا الشهر كدخل',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'حفظ التعديلات' : 'إضافة الدين'),
        ),
      ],
    );
  }

  Widget _curBtn(String label, bool sel, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.info.withValues(alpha: 0.18) : AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppColors.info : Colors.transparent),
          ),
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: sel ? AppColors.text : AppColors.muted)),
        ),
      );
}

// ---------------- التسديد ----------------
Future<void> openPaySheet(BuildContext context, Debt d) =>
    showAppSheet(context, _PayForm(debt: d));

class _PayForm extends StatefulWidget {
  final Debt debt;
  const _PayForm({required this.debt});

  @override
  State<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends State<_PayForm> {
  late final TextEditingController _amount;
  late final TextEditingController _rate;
  String _source = 'budget';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    final d = widget.debt;
    final rem = s.remaining(d);
    final def = d.minPayment > 0 && d.minPayment < rem ? d.minPayment : rem;
    _amount = TextEditingController(
        text: def % 1 == 0 ? def.toStringAsFixed(0) : def.toStringAsFixed(2));
    final r = s.usdToLocal;
    _rate = TextEditingController(
        text: r == null ? '' : (r >= 100 ? r.toStringAsFixed(0) : r.toStringAsFixed(2)));
  }

  @override
  void dispose() {
    _amount.dispose();
    _rate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final d = widget.debt;
    final rem = s.remaining(d);
    final needRate = d.usd && s.currency != '\$' && _source == 'budget';
    final amt = parseAmount(_amount.text) ?? 0;
    final rate = parseAmount(_rate.text) ?? 0;
    final wallet = s.walletBalance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('تسديد: ${d.name}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('المتبقي ${_amt(s, d, rem, dec: true)}',
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        AmountField(
            controller: _amount,
            label: 'مبلغ الدفعة',
            suffix: d.usd ? 'USD' : s.currency,
            autofocus: true),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () => setState(() => _amount.text =
                rem % 1 == 0 ? rem.toStringAsFixed(0) : rem.toStringAsFixed(2)),
            child: const Text('تسديد كامل المتبقي'),
          ),
        ),
        const Text('من أين الدفعة؟',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 8),
        _src('budget', 'من ميزانية هذا الشهر',
            'تُسجَّل كمصروف بفئة "سداد ديون"', Icons.account_balance_wallet_rounded),
        if (d.usd)
          _src('wallet', 'من محفظة الدولار',
              'الرصيد الحالي ${usd(wallet)}', Icons.savings_rounded),
        _src('none', 'تسجيل فقط', 'دُفعت سابقاً أو من مصدر آخر',
            Icons.edit_note_rounded),
        if (needRate) ...[
          const SizedBox(height: 10),
          AmountField(
              controller: _rate,
              label: 'سعر الدولار',
              suffix: '${s.currency} / \$'),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
                amt > 0 && rate > 0
                    ? 'سيُخصم من الميزانية ${money(amt * rate, s.currency, decimals: false)}'
                    : 'أدخل سعر الدولار لحساب المبلغ بالليرة',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            if (amt <= 0) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
              return;
            }
            if (needRate && rate <= 0) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('أدخل سعر الدولار')));
              return;
            }
            if (_source == 'wallet' && amt > wallet + 0.005) {
              messenger.showSnackBar(const SnackBar(
                  content: Text('رصيد محفظة الدولار لا يكفي')));
              return;
            }
            final pay = amt > rem ? rem : amt;
            s.payDebt(d, pay, source: _source, localRate: needRate ? rate : null);
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
            messenger.showSnackBar(SnackBar(
                content: Text(s.remaining(d) <= 0.005
                    ? 'مبروك! سدّدت هذا الدين بالكامل 🎉'
                    : 'تم تسجيل الدفعة ✓')));
          },
          child: const Text('تسجيل الدفعة'),
        ),
      ],
    );
  }

  Widget _src(String v, String title, String sub, IconData icon) {
    final sel = _source == v;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _source = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppColors.primary : Colors.transparent),
          ),
          child: Row(children: [
            Icon(icon, color: sel ? AppColors.primary : AppColors.muted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(sub,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            if (sel)
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ---------------- تفاصيل الدين ----------------
Future<void> openDebtDetails(BuildContext context, Debt d) =>
    showAppSheet(context, _DebtDetails(debtId: d.id));

class _DebtDetails extends StatelessWidget {
  final String debtId;
  const _DebtDetails({required this.debtId});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final d = s.debts.where((x) => x.id == debtId).firstOrNull;
    if (d == null) return const SizedBox(height: 40);
    final pays = s.paymentsFor(d.id);
    final rem = s.remaining(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(d.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              openDebtForm(context, existing: d);
            },
            icon: const Icon(Icons.edit_rounded, color: AppColors.muted),
          ),
          IconButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text('حذف الدين؟'),
                  content: const Text(
                      'سيُحذف الدين وكل دفعاته، ومعها المصاريف المسجّلة لهذه الدفعات.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('إلغاء')),
                    TextButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('حذف',
                            style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                Navigator.pop(context);
                s.deleteDebt(d.id);
              }
            },
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.danger),
          ),
        ]),
        Text(
            'المتبقي ${_amt(s, d, rem, dec: true)} من ${_amt(s, d, d.amount, dec: true)}'
            '${d.rate > 0 ? ' · فائدة ${d.rate}% سنوياً' : ''}',
            style: const TextStyle(color: AppColors.muted)),
        if (d.usd && s.currency != '\$' && s.usdToLocal != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'يعادل اليوم ${money(rem * s.usdToLocal!, s.currency, decimals: false)}',
                style: const TextStyle(color: AppColors.info, fontSize: 13)),
          ),
        if (rem > 0.005) ...[
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openPaySheet(context, d);
            },
            child: const Text('تسديد دفعة'),
          ),
        ],
        const SizedBox(height: 18),
        Text('الدفعات (${pays.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 8),
        if (pays.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('لم تسجّل أي دفعة بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted)),
          )
        else
          for (final p in pays)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                const Icon(Icons.check_rounded,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_amt(s, d, p.amount, dec: true),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                          '${dayLabel(p.date)} · ${switch (p.source) {
                            'budget' => 'من الميزانية',
                            'wallet' => 'من محفظة الدولار',
                            _ => 'تسجيل فقط',
                          }}',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => s.deleteDebtPayment(p.id),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.muted, size: 20),
                ),
              ]),
            ),
      ],
    );
  }
}

// ---------------- خطة السداد ----------------
class _PlanView extends StatefulWidget {
  final AppStore store;
  const _PlanView({required this.store});

  @override
  State<_PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<_PlanView> {
  late final TextEditingController _extra;
  DebtStrategy? _chosen;

  @override
  void initState() {
    super.initState();
    final v = widget.store.suggestedExtraPayment;
    _extra = TextEditingController(text: v > 0 ? v.toStringAsFixed(0) : '');
    _extra.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _extra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final cur = s.currency;
    String f(double v) => money(v, cur, decimals: false);
    if (s.activeDebts.isEmpty) {
      return const EmptyState(
        icon: Icons.celebration_rounded,
        title: 'لا توجد ديون قائمة',
        subtitle: 'عند إضافة دين ستظهر هنا خطة مفصّلة للتخلص منه',
      );
    }
    final debts = s.planDebts();
    if (debts == null) {
      return const EmptyState(
        icon: Icons.currency_exchange_rounded,
        title: 'نحتاج سعر الدولار',
        subtitle: 'لديك ديون بالدولار ولا يوجد سعر صرف حالياً. حدّث الأسعار من تبويب المدخرات',
      );
    }
    final extra = parseAmount(_extra.text) ?? 0;
    final snow = simulatePlan(debts, extra, DebtStrategy.snowball);
    final aval = simulatePlan(debts, extra, DebtStrategy.avalanche);
    final noExtra = simulatePlan(debts, 0, DebtStrategy.avalanche);
    final hasInterest = debts.any((d) => d.rate > 0);
    final saving = snow.totalInterest - aval.totalInterest;
    final recommended = (!hasInterest || saving < 1)
        ? DebtStrategy.snowball
        : DebtStrategy.avalanche;
    final strategy = _chosen ?? recommended;
    final plan = strategy == DebtStrategy.snowball ? snow : aval;
    final surplus = s.avgMonthlySurplus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('كم يمكنك أن تدفع زيادة شهرياً؟'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AmountField(
                  controller: _extra,
                  label: 'مبلغ إضافي فوق الأقساط',
                  suffix: cur),
              const SizedBox(height: 8),
              Text(
                  surplus > 0
                      ? 'متوسط ما يتبقى لك شهرياً ${f(surplus)}. نقترح تخصيص نصفه للسداد: ${f(s.suggestedExtraPayment)}'
                      : 'مصاريفك تقارب دخلك حالياً. خفّض الهدر لتوفير مبلغ للسداد.',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12.5, height: 1.5)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                for (final v in [0.25, 0.5, 0.75])
                  if (surplus > 0)
                    ActionChip(
                      label: Text('${(v * 100).round()}% من الفائض'),
                      onPressed: () => setState(
                          () => _extra.text = (surplus * v).toStringAsFixed(0)),
                    ),
              ]),
            ],
          ),
        ),
        if (!plan.feasible) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.danger.withValues(alpha: 0.12),
            child: Text(
                plan.monthlyBudget <= 0
                    ? 'لا توجد أقساط ولا مبلغ إضافي. حدّد مبلغاً شهرياً للسداد لنحسب لك الخطة.'
                    : 'المبلغ الشهري (${f(plan.monthlyBudget)}) لا يغطي الفوائد، فالدين لن ينتهي. ارفع الدفعة الشهرية.',
                style: const TextStyle(height: 1.6)),
          ),
        ] else ...[
          const SectionTitle('اختر الطريقة'),
          Row(children: [
            Expanded(
              child: _StrategyCard(
                title: 'كرة الثلج',
                sub: 'الأصغر أولاً',
                desc: 'إنجاز سريع يحفّزك على الاستمرار',
                r: snow,
                cur: cur,
                selected: strategy == DebtStrategy.snowball,
                recommended: recommended == DebtStrategy.snowball,
                onTap: () => setState(() => _chosen = DebtStrategy.snowball),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StrategyCard(
                title: 'الانهيار الجليدي',
                sub: 'الأعلى فائدة أولاً',
                desc: 'الأقل تكلفة إجمالاً',
                r: aval,
                cur: cur,
                selected: strategy == DebtStrategy.avalanche,
                recommended: recommended == DebtStrategy.avalanche,
                onTap: () => setState(() => _chosen = DebtStrategy.avalanche),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.primary.withValues(alpha: 0.10),
            child: Row(children: [
              const Icon(Icons.flag_rounded, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'تتحرر من كل ديونك خلال ${_monthsLabel(plan.months)} (${_inMonths(plan.months)}) '
                  'بدفعة شهرية ${f(plan.monthlyBudget)}'
                  '${noExtra.feasible && noExtra.months > plan.months ? '، أي أسرع بـ ${_monthsLabel(noExtra.months - plan.months)} من الأقساط وحدها' : ''}'
                  '${hasInterest && noExtra.feasible && noExtra.totalInterest - plan.totalInterest > 1 ? ' وتوفّر ${f(noExtra.totalInterest - plan.totalInterest)} فوائد' : ''}.',
                  style: const TextStyle(height: 1.6, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
          const SectionTitle('ترتيب السداد'),
          AppCard(
            child: Column(children: [
              for (var i = 0; i < plan.order.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(plan.order[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    Text(_inMonths(plan.order[i].month),
                        style: const TextStyle(color: AppColors.muted)),
                  ]),
                ),
            ]),
          ),
          const SectionTitle('كيف تطبّق الخطة'),
          const _Tips(tips: [
            ('ادفع الأقساط الدنيا لكل الديون في موعدها دائماً', Icons.event_available_rounded),
            ('وجّه كل المبلغ الإضافي للدين الأول في الترتيب فقط', Icons.my_location_rounded),
            ('عندما ينتهي دين، أضف قسطه إلى الدين التالي (لا تصرفه)', Icons.redo_rounded),
            ('أي دخل مفاجئ (مكافأة، بيع شيء) ضع نصفه على الديون', Icons.bolt_rounded),
            ('لا تأخذ ديناً جديداً أثناء الخطة إلا لطارئ حقيقي', Icons.block_rounded),
          ]),
          if (s.activeDebts.any((d) => d.usd) && cur != '\$')
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: _Tips(tips: [
                ('الديون بالدولار تكبر بالليرة كلما ارتفع سعر الصرف. إن أمكن، ابدأ بها أو سدّدها من مدخراتك بالدولار مباشرة', Icons.trending_up_rounded),
              ]),
            ),
        ],
      ],
    );
  }
}

class _StrategyCard extends StatelessWidget {
  final String title, sub, desc, cur;
  final PlanResult r;
  final bool selected, recommended;
  final VoidCallback onTap;
  const _StrategyCard({
    required this.title,
    required this.sub,
    required this.desc,
    required this.r,
    required this.cur,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recommended) const Pill('مقترحة', AppColors.primary),
            if (recommended) const SizedBox(height: 6),
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(sub,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 10),
            Text(_monthsLabel(r.months),
                style: const TextStyle(
                    fontWeight: FontWeight.w900, fontSize: 18)),
            if (r.totalInterest > 0.5)
              Text('فوائد ${money(r.totalInterest, cur, decimals: false)}',
                  style: const TextStyle(color: AppColors.warning, fontSize: 12)),
            const SizedBox(height: 6),
            Text(desc,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 11.5, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  final List<(String, IconData)> tips;
  const _Tips({required this.tips});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(children: [
        for (final t in tips)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(t.$2, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(t.$1,
                        style: const TextStyle(height: 1.55, fontSize: 13.5))),
              ],
            ),
          ),
      ]),
    );
  }
}

// ---------------- خطة عدم الاستدانة ----------------
class _NoDebtView extends StatelessWidget {
  final AppStore store;
  const _NoDebtView({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final cur = s.currency;
    String f(double v) => money(v, cur, decimals: false);
    final avgSpend = s.avgMonthlySpend;
    final target = avgSpend * 3;
    final savings = s.totalSavingsValue ??
        (cur == '\$' ? s.walletBalance : null);
    final ratio = (target > 0 && savings != null) ? savings / target : 0.0;
    final gap = (savings != null && target > savings) ? target - savings : 0.0;
    final income = s.current.income;
    final mins = s.monthlyMinPaymentsLocal ?? 0;
    final dti = income > 0 ? mins / income : 0.0;
    final last = s.lastMonths(6).where((m) => m.count > 0).toList();
    final deficits = last.where((m) => m.saved < 0).length;
    final surplus = s.avgMonthlySurplus;

    Widget check(bool ok, String title, String body, {bool warn = false}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                    ok
                        ? Icons.check_circle_rounded
                        : (warn
                            ? Icons.error_rounded
                            : Icons.radio_button_unchecked_rounded),
                    color: ok
                        ? AppColors.primary
                        : (warn ? AppColors.danger : AppColors.warning)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14.5)),
                      const SizedBox(height: 4),
                      Text(body,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.55)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('صندوق الطوارئ: درعك ضد الاستدانة'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  avgSpend <= 0
                      ? 'سجّل مصاريفك لنحسب حجم صندوق الطوارئ المناسب لك'
                      : 'الهدف: 3 أشهر من مصاريفك = ${f(target)}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ProgressBar(value: ratio, color: AppColors.primary, height: 10),
              const SizedBox(height: 8),
              Text(
                  savings == null
                      ? 'لا يمكن تقييم المدخرات بدون سعر الصرف'
                      : (avgSpend <= 0
                          ? 'مدخراتك الحالية ${f(savings)}'
                          : gap <= 0
                              ? 'ممتاز! مدخراتك ${f(savings)} تكفي للطوارئ 🎉'
                              : 'لديك ${f(savings)} (${pct(ratio)}). ادّخر ${f(gap / 6)} شهرياً لتكمله خلال 6 أشهر'),
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        const SectionTitle('فحص وضعك الحالي'),
        check(
          deficits == 0,
          deficits == 0
              ? 'لا عجز في آخر الأشهر'
              : 'عجز في $deficits ${deficits == 1 ? 'شهر' : 'أشهر'} من آخر ${last.length}',
          deficits == 0
              ? 'مصاريفك ضمن دخلك. هذا أهم شرط لعدم الحاجة للدين.'
              : 'عندما تتجاوز المصاريف الدخل يصبح الدين مسألة وقت. راجع تبويب الهدر وخفّض الكماليات أولاً.',
          warn: deficits > 0,
        ),
        check(
          dti <= 0.2,
          income <= 0
              ? 'نسبة الأقساط من الدخل'
              : 'الأقساط ${pct(dti)} من دخلك',
          income <= 0
              ? 'أضف دخلك الشهري لنحسب هذه النسبة.'
              : dti <= 0.2
                  ? 'نسبة آمنة (أقل من 20%).'
                  : dti <= 0.36
                      ? 'نسبة مرتفعة. لا تأخذ أي التزام جديد حتى تنخفض تحت 20%.'
                      : 'نسبة خطرة (أعلى من 36%). أوقف أي استدانة وركّز على خطة السداد.',
          warn: dti > 0.36,
        ),
        check(
          surplus > 0 && income > 0 && surplus >= income * 0.1,
          'هامش أمان شهري',
          surplus <= 0
              ? 'لا يتبقى لك شيء آخر الشهر. اجعل هدفك الأول أن يبقى 10% من دخلك على الأقل.'
              : 'يتبقى لك وسطياً ${f(surplus)} شهرياً${income > 0 ? ' (${pct(surplus / income)} من الدخل)' : ''}. الهدف 10% أو أكثر.',
        ),
        const SectionTitle('قواعد ذهبية لعدم الاستدانة'),
        const _Tips(tips: [
          ('لا تستدِن أبداً لشراء الكماليات أو الهدايا أو المناسبات، فقط للضرورات القصوى', Icons.block_rounded),
          ('قبل أي دين انتظر 48 ساعة واسأل: هل يمكن تأجيله أو شراء بديل أرخص؟', Icons.timer_rounded),
          ('خصّص "ظرفاً" شهرياً للمصاريف السنوية (المدارس، الأعياد، التصليحات): مجموعها السنوي ÷ 12', Icons.mail_rounded),
          ('اجعل الادخار أول مصروف عند استلام الراتب، وليس ما يتبقى آخر الشهر', Icons.savings_rounded),
          ('احتفظ بمدخراتك بالدولار أو الذهب لحمايتها من انخفاض الليرة، واستخدمها للطوارئ بدل الاستدانة', Icons.shield_rounded),
          ('إذا اضطررت للاستدانة: اتفق كتابياً على المبلغ والموعد، ولا تتجاوز الأقساط 20% من دخلك', Icons.handshake_rounded),
        ]),
      ],
    );
  }
}

/// بطاقة مختصرة للديون في الشاشة الرئيسية
class DebtsTile extends StatelessWidget {
  const DebtsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final total = s.totalDebtLocal;
    final has = s.activeDebts.isNotEmpty;
    final plan = s.planDebts();
    final r = plan == null || !has
        ? null
        : simulatePlan(plan, s.suggestedExtraPayment, DebtStrategy.avalanche);
    return AppCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const DebtsScreen())),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: (has ? AppColors.danger : AppColors.primary)
                .withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(has ? Icons.request_quote_rounded : Icons.verified_rounded,
              color: has ? AppColors.danger : AppColors.primary, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  has
                      ? 'ديون متبقية: ${total == null ? '—' : money(total, s.currency, decimals: false)}'
                      : 'لا ديون عليك',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 3),
              Text(
                  has
                      ? (r != null && r.feasible
                          ? 'بالخطة المقترحة تتحرر منها في ${_inMonths(r.months)}'
                          : 'افتح خطة السداد')
                      : 'سجّل ديونك، أو اطّلع على خطة عدم الاستدانة',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
        const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
      ]),
    );
  }
}
