import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_expense.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int _filter = 0; // 0 الكل، 1 ضروري، 2 غير ضروري
  String? _cat;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    var list = s.expensesIn(s.selectedMonth);
    if (_filter == 1) list = list.where((e) => e.essential).toList();
    if (_filter == 2) list = list.where((e) => !e.essential).toList();
    if (_cat != null) list = list.where((e) => e.categoryId == _cat).toList();
    final total = list.fold<double>(0, (a, e) => a + e.amount);

    // تجميع حسب اليوم
    final groups = <String, List<Expense>>{};
    for (final e in list) {
      groups.putIfAbsent(dayLabel(e.date), () => []).add(e);
    }

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
            pinned: true, toolbarHeight: 64, title: Text('المصاريف')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          sliver: SliverList.list(children: [
            Row(children: [
              const MonthSwitcher(),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('الإجمالي',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text(money(total, s.currency, decimals: false),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ]),
            const SizedBox(height: 14),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _chip('الكل', _filter == 0 && _cat == null,
                      () => setState(() {
                            _filter = 0;
                            _cat = null;
                          })),
                  _chip('ضروري', _filter == 1,
                      () => setState(() => _filter = _filter == 1 ? 0 : 1)),
                  _chip('غير ضروري', _filter == 2,
                      () => setState(() => _filter = _filter == 2 ? 0 : 2),
                      color: AppColors.warning),
                  const SizedBox(width: 6),
                  for (final c in kCategories)
                    _chip(c.name, _cat == c.id,
                        () => setState(() => _cat = _cat == c.id ? null : c.id),
                        color: c.color),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ]),
        ),
        if (list.isEmpty)
          const SliverToBoxAdapter(
            child: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'لا توجد مصاريف',
              subtitle: 'لا يوجد ما يطابق هذا الشهر أو الفلتر المختار',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(children: [
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
                  child: Row(children: [
                    Text(g.key,
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    const Spacer(),
                    Text(
                        money(g.value.fold<double>(0, (a, e) => a + e.amount),
                            s.currency,
                            decimals: false),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13)),
                  ]),
                ),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(children: [
                    for (final e in g.value)
                      Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: AlignmentDirectional.centerEnd,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Icon(Icons.delete_rounded,
                              color: AppColors.danger),
                        ),
                        onDismissed: (_) {
                          s.deleteExpense(e.id);
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(SnackBar(
                              content: const Text('تم حذف المصروف'),
                              action: SnackBarAction(
                                label: 'تراجع',
                                textColor: AppColors.primary,
                                onPressed: () => s.addExpense(e),
                              ),
                            ));
                        },
                        child: ExpenseTile(e,
                            onTap: () =>
                                openExpenseSheet(context, existing: e)),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {Color color = AppColors.primary}) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.text : AppColors.muted,
              )),
        ),
      ),
    );
  }
}
