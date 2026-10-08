import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../insights.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_expense.dart';

/// شاشة الإنفاق غير الضروري (الهدر)
class WasteScreen extends StatefulWidget {
  const WasteScreen({super.key});

  @override
  State<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends State<WasteScreen> {
  double _cut = 0.5; // نسبة التخفيض في المحاكي

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final m = s.current;
    final cur = s.currency;
    final items = s
        .expensesIn(s.selectedMonth)
        .where((e) => !e.essential)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    final cats = topWasteCategories(s);

    final monthlySave = m.waste * _cut;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
            pinned: true, toolbarHeight: 64, title: Text('الهدر')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(children: [
            const Align(
                alignment: AlignmentDirectional.centerStart,
                child: MonthSwitcher()),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.all(22),
              gradient: const LinearGradient(
                begin: AlignmentDirectional.topStart,
                end: AlignmentDirectional.bottomEnd,
                colors: [Color(0xFF8A4B12), Color(0xFF5A2A1A), Color(0xFF2A1A22)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: Color(0xFFFFC879)),
                    const SizedBox(width: 8),
                    Text('مال صُرف بدون هدف',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8))),
                  ]),
                  const SizedBox(height: 8),
                  Text(money(m.waste, cur, decimals: false),
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    m.spent > 0
                        ? '${pct(m.wasteRatio)} من مصاريفك · ${m.income > 0 ? '${pct(m.waste / m.income)} من دخلك' : ''}'
                        : 'لا توجد مصاريف بعد',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  ProgressBar(
                      value: m.wasteRatio,
                      color: const Color(0xFFFFB547),
                      height: 8),
                ],
              ),
            ),
            if (m.waste > 0) ...[
              const SectionTitle('محاكي التوفير'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('لو خفّضت الإنفاق غير الضروري بنسبة ${pct(_cut)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Slider(
                      value: _cut,
                      min: 0.1,
                      max: 1,
                      divisions: 9,
                      label: pct(_cut),
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => _cut = v);
                      },
                    ),
                    Row(children: [
                      _saveBox('شهرياً', money(monthlySave, cur, decimals: false)),
                      const SizedBox(width: 10),
                      _saveBox('سنوياً',
                          money(monthlySave * 12, cur, decimals: false)),
                      const SizedBox(width: 10),
                      _saveBox('5 سنوات',
                          money(monthlySave * 60, cur, decimals: false)),
                    ]),
                    if (m.income > 0) ...[
                      const SizedBox(height: 12),
                      Text(
                        'معدل ادخارك سيرتفع من ${pct(m.savingsRate)} إلى ${pct((m.saved + monthlySave) / m.income)}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (cats.isNotEmpty) ...[
              const SectionTitle('أين يذهب الهدر؟'),
              AppCard(
                child: Column(children: [
                  for (final c in cats)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(children: [
                        CategoryAvatar(c.key, size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(c.key.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                Text(money(c.value, cur, decimals: false),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                              ]),
                              const SizedBox(height: 6),
                              ProgressBar(
                                  value: m.waste > 0 ? c.value / m.waste : 0,
                                  color: c.key.color,
                                  height: 6),
                            ],
                          ),
                        ),
                      ]),
                    ),
                ]),
              ),
            ],
            SectionTitle('المصاريف غير الضرورية (${items.length})'),
            if (items.isEmpty)
              const EmptyState(
                icon: Icons.verified_rounded,
                title: 'لا يوجد هدر هذا الشهر',
                subtitle:
                    'عند إضافة مصروف اختر "غير ضروري" للأشياء التي كان يمكنك الاستغناء عنها',
              )
            else ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Text(
                    'اضغط مطوّلاً على أي مصروف لنقله إلى "ضروري"',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
              ),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Column(children: [
                  for (final e in items)
                    GestureDetector(
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        s.updateExpense(e.copyWith(essential: true));
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نقله إلى ضروري')));
                      },
                      child: ExpenseTile(e,
                          onTap: () => openExpenseSheet(context, existing: e)),
                    ),
                ]),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _saveBox(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16)),
            ),
          ]),
        ),
      );
}
