import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final bal = s.walletBalance;
    final now = DateTime.now();
    final thisMonthIn = s.wallet
        .where((t) =>
            t.amount > 0 && t.date.year == now.year && t.date.month == now.month)
        .fold<double>(0, (a, t) => a + t.amount);
    final totalIn =
        s.wallet.where((t) => t.amount > 0).fold<double>(0, (a, t) => a + t.amount);
    final totalOut = s.wallet
        .where((t) => t.amount < 0)
        .fold<double>(0, (a, t) => a + t.amount)
        .abs();

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
            pinned: true, toolbarHeight: 64, title: Text('محفظة الدولار')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(children: [
            AppCard(
              padding: const EdgeInsets.all(22),
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF1E3A8A), Color(0xFF173058), Color(0xFF0F2A2A)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('USD',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                    const Spacer(),
                    Icon(Icons.savings_rounded,
                        color: Colors.white.withValues(alpha: 0.7)),
                  ]),
                  const SizedBox(height: 18),
                  Text('الرصيد المدّخر',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(usd(bal),
                        style: const TextStyle(
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                  ),
                  const SizedBox(height: 6),
                  Text('أُضيف هذا الشهر: ${usd(thisMonthIn)}',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.add_rounded,
                        label: 'إيداع',
                        filled: true,
                        onTap: () => _openTx(context, deposit: true),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionBtn(
                        icon: Icons.remove_rounded,
                        label: 'سحب',
                        onTap: () => _openTx(context, deposit: false),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _GoalCard(store: s),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                  child: _mini('إجمالي الإيداعات', usd(totalIn),
                      AppColors.primary, Icons.south_west_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: _mini('إجمالي السحوبات', usd(totalOut),
                      AppColors.danger, Icons.north_east_rounded)),
            ]),
            SectionTitle('سجل الحركات (${s.wallet.length})'),
            if (s.wallet.isEmpty)
              const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'المحفظة فارغة',
                subtitle:
                    'أضف المبلغ الذي ادّخرته بالدولار، وكل مبلغ جديد تحتفظ به',
              )
            else
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(children: [
                  for (final t in s.wallet)
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
                        s.deleteWalletTx(t.id);
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: const Text('تم حذف الحركة'),
                            action: SnackBarAction(
                                label: 'تراجع',
                                textColor: AppColors.primary,
                                onPressed: () => s.addWalletTx(t)),
                          ));
                      },
                      child: _TxTile(t),
                    ),
                ]),
              ),
          ]),
        ),
      ],
    );
  }

  Widget _mini(String label, String value, Color color, IconData icon) =>
      AppCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
              ],
            ),
          ),
        ]),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.white : Colors.white.withValues(alpha: 0.12),
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
              Icon(icon,
                  color: filled ? const Color(0xFF173058) : Colors.white,
                  size: 20),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: filled ? const Color(0xFF173058) : Colors.white,
                      fontWeight: FontWeight.w800)),
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
            child: Text('حدّد هدفاً للادخار لتتابع تقدّمك',
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
                ? '🎉 حققت هدفك! يمكنك رفع الهدف من الإعدادات'
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
  const _TxTile(this.t);

  @override
  Widget build(BuildContext context) {
    final dep = t.amount >= 0;
    final c = dep ? AppColors.primary : AppColors.danger;
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
              dep ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: c,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.note.isEmpty ? (dep ? 'إيداع' : 'سحب') : t.note,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 3),
              Text(dayLabel(t.date),
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ],
          ),
        ),
        Text('${dep ? '+' : ''}${usd(t.amount)}',
            style: TextStyle(
                color: c, fontWeight: FontWeight.w800, fontSize: 15.5)),
      ]),
    );
  }
}

void _openTx(BuildContext context, {required bool deposit}) {
  final s = context.read<AppStore>();
  final amount = TextEditingController();
  final note = TextEditingController();
  showAppSheet(
    context,
    Builder(builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(deposit ? 'إيداع في المحفظة' : 'سحب من المحفظة',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              deposit
                  ? 'أدخل المبلغ الذي احتفظت به بالدولار'
                  : 'الرصيد الحالي: ${usd(s.walletBalance)}',
              style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          AmountField(
              controller: amount,
              label: 'المبلغ',
              suffix: 'USD',
              autofocus: true),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            decoration: InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              hintText: deposit ? 'مثال: ادخار راتب الشهر' : 'مثال: إصلاح السيارة',
            ),
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
