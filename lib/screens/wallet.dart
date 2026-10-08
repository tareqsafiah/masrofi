import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../rates.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

const _gold = Color(0xFFF5C451);

/// شاشة المدخرات: دولار + ذهب
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _tab = 0; // 0 دولار، 1 ذهب

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final txs = s.wallet
        .where((t) => _tab == 0 ? t.asset == 'usd' : t.asset != 'usd')
        .toList();

    return RefreshIndicator(
      onRefresh: s.refreshRates,
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
              pinned: true, toolbarHeight: 64, title: Text('المدخرات')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(children: [
              _TotalCard(store: s),
              const SizedBox(height: 12),
              _RatesCard(store: s),
              const SizedBox(height: 16),
              _Tabs(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
              const SizedBox(height: 14),
              if (_tab == 0) ...[
                _UsdCard(store: s),
                const SizedBox(height: 12),
                _GoalCard(store: s),
              ] else
                _GoldCard(store: s),
              SectionTitle('سجل الحركات (${txs.length})'),
              if (txs.isEmpty)
                EmptyState(
                  icon: _tab == 0
                      ? Icons.account_balance_wallet_outlined
                      : Icons.diamond_outlined,
                  title: _tab == 0 ? 'لا توجد حركات دولار' : 'لا يوجد ذهب بعد',
                  subtitle: _tab == 0
                      ? 'سجّل الدولارات التي اشتريتها أو ادّخرتها'
                      : 'سجّل الذهب الذي تشتريه وسيُحسب سعره يومياً',
                )
              else
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(children: [
                    for (final t in txs)
                      Dismissible(
                        key: ValueKey(t.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete_rounded,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) {
                          final linked = s.incomeForTx(t.id);
                          s.deleteWalletTx(t.id);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: const Text('تم حذف الحركة'),
                              action: SnackBarAction(
                                  label: 'تراجع',
                                  textColor: AppColors.primary,
                                  onPressed: () =>
                                      s.restoreWalletTx(t, linked)),
                            ));
                        },
                        child: _TxTile(t, currency: s.currency),
                      ),
                  ]),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TotalCard extends StatelessWidget {
  final AppStore store;
  const _TotalCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final total = s.totalSavingsValue;
    final usdQty = s.holding(Asset.usd);
    final g21 = s.holding(Asset.gold21);
    final g18 = s.holding(Asset.gold18);
    return AppCard(
      padding: const EdgeInsets.all(22),
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [Color(0xFF1E3A8A), Color(0xFF173058), Color(0xFF3A2E12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('قيمة مدخراتك اليوم',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              total != null
                  ? money(total, s.currency, decimals: false)
                  : usdFmt(usdQty),
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Colors.white),
            ),
          ),
          if (total == null)
            Text('أدخل سعر الصرف أو انتظر جلب الأسعار لحساب القيمة الكاملة',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          const SizedBox(height: 16),
          Row(children: [
            _chip('دولار', usdFmt(usdQty)),
            _chip('ذهب 21', '${_g(g21)} غ'),
            _chip('ذهب 18', '${_g(g18)} غ'),
          ]),
        ],
      ),
    );
  }

  static String _g(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Widget _chip(String label, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
            ),
          ],
        ),
      );
}

String usdFmt(double v) => usd(v);

class _RatesCard extends StatelessWidget {
  final AppStore store;
  const _RatesCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final r = s.rates;
    String p(Asset a, bool buy) {
      final v = s.marketPrice(a, buy: buy);
      return v == null ? '—' : money(v, s.currency, decimals: v < 100);
    }

    final canShow = r != null && (s.isSyp || s.currency == '\$');
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.trending_up_rounded,
                color: AppColors.info, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('أسعار اليوم · الليرة اليوم',
                  style:
                      TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
            ),
            s.ratesLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: s.refreshRates,
                    icon: const Icon(Icons.refresh_rounded,
                        color: AppColors.muted)),
          ]),
          if (!canShow)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 8),
              child: Text(
                r == null
                    ? 'تعذّر جلب الأسعار الآن. يمكنك إدخال السعر يدوياً عند الشراء أو البيع.'
                    : 'الأسعار التلقائية متاحة عند اختيار الليرة السورية أو الدولار كعملة.',
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 12.5, height: 1.5),
              ),
            )
          else ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Table(
                columnWidths: const {
                  0: FlexColumnWidth(1.2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                },
                children: [
                  _row('', 'شراء', 'مبيع', header: true),
                  if (s.currency != '\$')
                    _row('دولار', p(Asset.usd, false), p(Asset.usd, true)),
                  _row('ذهب 21 /غ', p(Asset.gold21, false),
                      p(Asset.gold21, true)),
                  _row('ذهب 18 /غ', p(Asset.gold18, false),
                      p(Asset.gold18, true)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'آخر تحديث: ${dayLabel(r!.fetchedAt)} ${r.fetchedAt.toLocal().hour.toString().padLeft(2, '0')}:${r.fetchedAt.toLocal().minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TableRow _row(String a, String b, String c, {bool header = false}) {
    final st = TextStyle(
      fontSize: header ? 11.5 : 13.5,
      color: header ? AppColors.muted : AppColors.text,
      fontWeight: header ? FontWeight.w500 : FontWeight.w700,
    );
    return TableRow(children: [
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(a,
              style: header
                  ? st
                  : st.copyWith(
                      fontWeight: FontWeight.w500, color: AppColors.muted))),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(b, style: st)),
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(c, style: st)),
    ]);
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget t(int i, String label, IconData icon, Color color) => Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(i);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: i == index
                    ? color.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 18, color: i == index ? color : AppColors.muted),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: i == index ? color : AppColors.muted)),
                ],
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        t(0, 'الدولار', Icons.attach_money_rounded, AppColors.primary),
        t(1, 'الذهب', Icons.diamond_rounded, _gold),
      ]),
    );
  }
}

class _UsdCard extends StatelessWidget {
  final AppStore store;
  const _UsdCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    final bal = s.walletBalance;
    final value = s.holdingValue(Asset.usd);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('USD',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12)),
            ),
            const Spacer(),
            if (s.isSyp && value != null && bal != 0)
              Text('≈ ${money(value, s.currency, decimals: false)}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Text(usd(bal),
              style:
                  const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          if (s.isSyp) ...[
            Row(children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.add_shopping_cart_rounded,
                  label: 'شراء دولار',
                  color: AppColors.primary,
                  filled: true,
                  onTap: () => openTradeSheet(context, gold: false, buy: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.sell_rounded,
                  label: 'بيع دولار',
                  color: AppColors.warning,
                  onTap: () => openTradeSheet(context, gold: false, buy: false),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              TextButton.icon(
                onPressed: () => _openPlainTx(context, deposit: true),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إيداع دولار بدون شراء'),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => _openPlainTx(context, deposit: false),
                child: const Text('سحب',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ]),
          ] else
            Row(children: [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.add_rounded,
                  label: 'إيداع',
                  color: AppColors.primary,
                  filled: true,
                  onTap: () => _openPlainTx(context, deposit: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionBtn(
                  icon: Icons.remove_rounded,
                  label: 'سحب',
                  color: AppColors.danger,
                  onTap: () => _openPlainTx(context, deposit: false),
                ),
              ),
            ]),
        ],
      ),
    );
  }
}

class _GoldCard extends StatelessWidget {
  final AppStore store;
  const _GoldCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final s = store;
    Widget k(Asset a, String label) {
      final g = s.holding(a);
      final v = s.holdingValue(a);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: _gold, fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 6),
              Text('${_TotalCard._g(g)} غ',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                    v == null
                        ? '—'
                        : '≈ ${money(v, s.currency, decimals: false)}',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12.5)),
              ),
            ],
          ),
        ),
      );
    }

    return AppCard(
      child: Column(children: [
        Row(children: [
          k(Asset.gold21, 'عيار 21'),
          const SizedBox(width: 10),
          k(Asset.gold18, 'عيار 18'),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _ActionBtn(
              icon: Icons.add_shopping_cart_rounded,
              label: 'شراء ذهب',
              color: _gold,
              filled: true,
              onTap: () => openTradeSheet(context, gold: true, buy: true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionBtn(
              icon: Icons.sell_rounded,
              label: 'بيع ذهب',
              color: AppColors.warning,
              onTap: () => openTradeSheet(context, gold: true, buy: false),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    final fg = filled ? const Color(0xFF0D1015) : color;
    return Material(
      color: filled ? color : color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg, size: 19),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final AppStore store;
  const _GoalCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final goal = store.savingsGoal;
    final bal = store.walletBalance;
    if (goal <= 0) {
      return AppCard(
        onTap: () => _openGoal(context),
        padding: const EdgeInsets.all(16),
        child: const Row(children: [
          Icon(Icons.flag_rounded, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text('حدّد هدفاً للادخار بالدولار لتتابع تقدّمك',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          Icon(Icons.chevron_left_rounded, color: AppColors.muted),
        ]),
      );
    }
    final p = (bal / goal).clamp(0.0, 1.0);
    final left = goal - bal;
    return AppCard(
      onTap: () => _openGoal(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.flag_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(store.goalName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ),
            Text(pct(p),
                style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          ProgressBar(value: p, color: AppColors.primary, height: 10),
          const SizedBox(height: 10),
          Text(
            left <= 0
                ? '🎉 حققت هدفك! اضغط لرفع الهدف'
                : 'متبقٍّ ${usd(left)} من أصل ${usd(goal)}',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _openGoal(BuildContext context) {
    final s = context.read<AppStore>();
    final amount = TextEditingController(
        text: s.savingsGoal > 0 ? s.savingsGoal.toStringAsFixed(0) : '');
    final name = TextEditingController(text: s.goalName);
    showAppSheet(
      context,
      Builder(builder: (ctx) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('هدف الادخار',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'اسم الهدف')),
            const SizedBox(height: 12),
            AmountField(
                controller: amount, label: 'المبلغ المستهدف', suffix: 'USD'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                s.updateSettings(
                  savingsGoal: parseAmount(amount.text) ?? 0,
                  goalName:
                      name.text.trim().isEmpty ? 'هدفي' : name.text.trim(),
                );
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        );
      }),
    );
  }
}

class _TxTile extends StatelessWidget {
  final WalletTx t;
  final String currency;
  const _TxTile(this.t, {required this.currency});

  @override
  Widget build(BuildContext context) {
    final a = AssetX.fromKey(t.asset);
    final isGold = a != Asset.usd;
    final dep = t.amount >= 0;
    final c = isGold ? _gold : (dep ? AppColors.primary : AppColors.danger);
    final qty = t.amount.abs();
    final q = qty == qty.roundToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2);
    final title = t.note.isNotEmpty
        ? t.note
        : t.isTrade
            ? '${dep ? 'شراء' : 'بيع'} ${isGold ? a.label : 'دولار'}'
            : (dep ? 'إيداع' : 'سحب');
    final sub = t.isTrade
        ? '${dayLabel(t.date)} · بسعر ${money(t.price!, currency, decimals: t.price! < 100)} · ${dep ? 'دفعت' : 'قبضت'} ${money(t.total!, currency, decimals: false)}'
        : dayLabel(t.date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
              isGold
                  ? Icons.diamond_rounded
                  : (dep ? Icons.south_west_rounded : Icons.north_east_rounded),
              color: c,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 3),
              Text(sub,
                  maxLines: 2,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12, height: 1.4)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
            isGold
                ? '${dep ? '+' : '-'}$q غ'
                : '${dep ? '+' : '-'}${usd(qty)}',
            style: TextStyle(
                color: dep ? (isGold ? _gold : AppColors.primary) : AppColors.danger,
                fontWeight: FontWeight.w800,
                fontSize: 15)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// إيداع/سحب دولار بدون عملية شراء أو بيع

void _openPlainTx(BuildContext context, {required bool deposit}) {
  final s = context.read<AppStore>();
  final amount = TextEditingController();
  final note = TextEditingController();
  showAppSheet(
    context,
    Builder(builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(deposit ? 'إيداع دولار' : 'سحب دولار',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              deposit
                  ? 'لدولارات حصلت عليها مباشرة (راتب، حوالة...)، بدون أن تُخصم من ميزانيتك'
                  : 'الرصيد الحالي: ${usd(s.walletBalance)}. السحب لا يُضاف للميزانية؛ لذلك استخدم "بيع دولار"',
              style: const TextStyle(color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 16),
          AmountField(
              controller: amount,
              label: 'المبلغ',
              suffix: 'USD',
              autofocus: true),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: deposit
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white),
            onPressed: () {
              final v = parseAmount(amount.text);
              if (v == null || v <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
                return;
              }
              s.addWalletTx(WalletTx(
                id: s.newId(),
                amount: deposit ? v : -v,
                date: DateTime.now(),
                note: note.text.trim(),
              ));
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
            },
            child: Text(deposit ? 'إيداع' : 'سحب'),
          ),
        ],
      );
    }),
  );
}

// ---------------------------------------------------------------------------
// شراء/بيع دولار أو ذهب بسعر قابل للتعديل

Future<void> openTradeSheet(BuildContext context,
    {required bool gold, required bool buy}) {
  return showAppSheet(context, TradeForm(gold: gold, buy: buy));
}

class TradeForm extends StatefulWidget {
  final bool gold;
  final bool buy;
  const TradeForm({super.key, required this.gold, required this.buy});

  @override
  State<TradeForm> createState() => _TradeFormState();
}

class _TradeFormState extends State<TradeForm> {
  late Asset _asset;
  final _qty = TextEditingController();
  final _price = TextEditingController();
  final _total = TextEditingController();
  bool _lastEditedTotal = true;
  bool _priceEdited = false;
  bool _syncing = false;
  bool _init = true;

  @override
  void initState() {
    super.initState();
    _asset = widget.gold ? Asset.gold21 : Asset.usd;
    // في شراء الدولار نبدأ من المبلغ بالليرة، وفي الباقي من الكمية
    _lastEditedTotal = !widget.gold && widget.buy;
    _setMarketPrice();
    _qty.addListener(() => _onChanged(fromTotal: false));
    _total.addListener(() => _onChanged(fromTotal: true));
    _price.addListener(() {
      if (_syncing) return;
      _priceEdited = true;
      _recalc();
    });
    _init = false;
  }

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _total.dispose();
    super.dispose();
  }

  double? get _market =>
      context.read<AppStore>().marketPrice(_asset, buy: widget.buy);

  void _setMarketPrice() {
    final m = _market;
    _syncing = true;
    _price.text = m == null ? '' : _fmt(m);
    _syncing = false;
    _priceEdited = false;
    _recalc();
  }

  String _fmt(double v) {
    if (v >= 1000) return v.toStringAsFixed(0);
    if (v >= 1) return double.parse(v.toStringAsFixed(2)).toString();
    return double.parse(v.toStringAsFixed(4)).toString();
  }

  void _onChanged({required bool fromTotal}) {
    if (_syncing) return;
    _lastEditedTotal = fromTotal;
    _recalc();
  }

  void _recalc() {
    final p = parseAmount(_price.text);
    _syncing = true;
    if (p != null && p > 0) {
      if (_lastEditedTotal) {
        final t = parseAmount(_total.text);
        _qty.text = t == null ? '' : _fmt(t / p);
      } else {
        final q = parseAmount(_qty.text);
        _total.text = q == null ? '' : _fmt(q * p);
      }
    }
    _syncing = false;
    if (mounted && !_init) setState(() {});
  }

  void _save() {
    final s = context.read<AppStore>();
    final q = parseAmount(_qty.text);
    final p = parseAmount(_price.text);
    if (p == null || p <= 0) {
      _err('أدخل سعر الوحدة');
      return;
    }
    if (q == null || q <= 0) {
      _err('أدخل الكمية أو المبلغ');
      return;
    }
    if (!widget.buy && q > s.holding(_asset) + 0.0001) {
      _err('لا تملك هذه الكمية (المتاح: ${_fmt(s.holding(_asset))} ${_asset.unit})');
      return;
    }
    s.trade(_asset, buy: widget.buy, qty: q, price: p);
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
        content: Text(widget.buy
            ? 'تمت إضافة ${_fmt(q)} ${_asset.unit} إلى مدخراتك'
            : 'أُضيف ${money(q * p, s.currency, decimals: false)} إلى ميزانية هذا الشهر')));
  }

  void _err(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final cur = s.currency;
    final m = _market;
    // إن وصلت الأسعار بعد فتح النافذة نملأ السعر تلقائياً
    if (_price.text.isEmpty && m != null && !_priceEdited) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _price.text.isEmpty) _setMarketPrice();
      });
    }
    final p = parseAmount(_price.text);
    final q = parseAmount(_qty.text);
    final color = widget.gold ? _gold : AppColors.primary;
    final title = '${widget.buy ? 'شراء' : 'بيع'} ${widget.gold ? 'ذهب' : 'دولار'}';
    final unitLabel = widget.gold ? 'الوزن' : 'المبلغ بالدولار';
    final totalLabel = widget.buy ? 'المبلغ الذي ستدفعه' : 'المبلغ الذي ستقبضه';
    final priceLabel = widget.gold
        ? 'سعر الغرام (${widget.buy ? 'مبيع' : 'شراء'})'
        : 'سعر الصرف (${widget.buy ? 'مبيع' : 'شراء'})';

    final qtyField = AmountField(
        controller: _qty, label: unitLabel, suffix: _asset.unit);
    final totalField =
        AmountField(controller: _total, label: totalLabel, suffix: cur);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(
          widget.buy
              ? 'يُسجَّل كتحويل من ميزانيتك إلى المدخرات، ولا يُحسب مصروفاً.'
              : 'الثمن يُضاف إلى ميزانية هذا الشهر كدخل إضافي.',
          style: const TextStyle(color: AppColors.muted, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (widget.gold) ...[
          Row(children: [
            for (final a in [Asset.gold21, Asset.gold18]) ...[
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _asset = a);
                    _setMarketPrice();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _asset == a
                          ? _gold.withValues(alpha: 0.16)
                          : AppColors.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: _asset == a ? _gold : Colors.transparent),
                    ),
                    child: Text(a == Asset.gold21 ? 'عيار 21' : 'عيار 18',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _asset == a ? _gold : AppColors.muted)),
                  ),
                ),
              ),
              if (a == Asset.gold21) const SizedBox(width: 10),
            ],
          ]),
          const SizedBox(height: 14),
        ],
        // الحقل الأساسي أولاً
        if (!widget.gold && widget.buy) totalField else qtyField,
        const SizedBox(height: 12),
        AmountField(controller: _price, label: priceLabel, suffix: cur),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
          child: Row(children: [
            Expanded(
              child: Text(
                m == null
                    ? (s.ratesLoading
                        ? 'جارٍ جلب سعر السوق...'
                        : 'سعر السوق غير متاح، أدخل السعر يدوياً')
                    : 'سعر السوق: ${money(m, cur, decimals: m < 100)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ),
            if (m != null && _priceEdited)
              TextButton(
                onPressed: _setMarketPrice,
                child: const Text('استخدم سعر السوق'),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        if (!widget.gold && widget.buy) qtyField else totalField,
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            (q != null && p != null && q > 0)
                ? widget.buy
                    ? 'ستدفع ${money(q * p, cur, decimals: false)} وتحصل على ${_fmt(q)} ${_asset.unit}'
                    : 'ستبيع ${_fmt(q)} ${_asset.unit} وتقبض ${money(q * p, cur, decimals: false)}'
                : 'أدخل ${!widget.gold && widget.buy ? 'المبلغ بالعملة المحلية' : 'الكمية'} لحساب النتيجة',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, height: 1.5),
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: widget.buy ? color : AppColors.warning,
            foregroundColor: const Color(0xFF0D1015),
          ),
          onPressed: _save,
          child: Text(widget.buy ? 'تأكيد الشراء' : 'تأكيد البيع'),
        ),
      ],
    );
  }
}
