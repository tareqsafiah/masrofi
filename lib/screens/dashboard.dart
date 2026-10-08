import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../insights.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'add_expense.dart';
import 'cloud_setup.dart';
import 'settings.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tab) goTo;
  const DashboardScreen({super.key, required this.goTo});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final m = s.current;
    final cur = s.currency;
    final insights = buildInsights(s);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 64,
          title: const Text('مصروفي'),
          actions: [
            SyncBadge(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
            IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(children: [
            const Align(
                alignment: AlignmentDirectional.centerStart,
                child: MonthSwitcher()),
            const SizedBox(height: 14),
            _HeroCard(m: m, currency: cur),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.today_rounded,
                  label: 'معدل الصرف اليومي',
                  value: money(m.dailyAvg, cur, decimals: false),
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.data_usage_rounded,
                  label: 'معدل الاستهلاك',
                  value: m.income > 0 ? pct(m.consumptionRate) : '—',
                  sub: 'من الدخل',
                  color: m.consumptionRate > 0.9
                      ? AppColors.danger
                      : AppColors.warning,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.local_fire_department_rounded,
                  label: 'إنفاق غير ضروري',
                  value: money(m.waste, cur, decimals: false),
                  sub: m.spent > 0 ? '${pct(m.wasteRatio)} من المصاريف' : null,
                  color: AppColors.warning,
                  onTap: () => goTo(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'محفظة الدولار',
                  value: usd(s.walletBalance),
                  color: AppColors.primary,
                  onTap: () => goTo(3),
                ),
              ),
            ]),
            if (s.isCurrentMonth && m.count > 0) ...[
              const SizedBox(height: 12),
              _ProjectionCard(m: m, store: s),
            ],
            if (m.byCategory.isNotEmpty) ...[
              const SectionTitle('توزيع المصاريف'),
              _CategoryBreakdown(m: m, currency: cur),
            ],
            const SectionTitle('آخر 6 أشهر'),
            _TrendChart(months: s.lastMonths(6), currency: cur),
            if (insights.isNotEmpty) ...[
              SectionTitle('نصيحة اليوم',
                  trailing: TextButton(
                      onPressed: () => goTo(4),
                      child: const Text('المزيد'))),
              InsightCard(insights.first),
            ],
            if (m.count > 0) ...[
              SectionTitle('آخر المصاريف',
                  trailing: TextButton(
                      onPressed: () => goTo(1), child: const Text('الكل'))),
              AppCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(children: [
                  for (final e in s.expensesIn(s.selectedMonth).take(4))
                    ExpenseTile(e,
                        onTap: () => openExpenseSheet(context, existing: e)),
                ]),
              ),
            ] else
              const EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'لا توجد مصاريف لهذا الشهر',
                subtitle: 'اضغط زر + لإضافة أول مصروف',
              ),
          ]),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final MonthStats m;
  final String currency;
  const _HeroCard({required this.m, required this.currency});

  @override
  Widget build(BuildContext context) {
    final saved = m.saved;
    final positive = saved >= 0;
    return AppCard(
      padding: const EdgeInsets.all(22),
      gradient: const LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [Color(0xFF14A37A), Color(0xFF0E6B5A), Color(0xFF123A45)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المدّخر هذا الشهر',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75), fontSize: 14)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(money(saved, currency, decimals: false),
                      style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5)),
                ),
              ),
              const SizedBox(width: 10),
              if (m.income > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${positive ? '▲' : '▼'} ${pct(m.savingsRate.abs())}',
                    style: TextStyle(
                        color: positive
                            ? const Color(0xFFB7FFE6)
                            : const Color(0xFFFFC2C2),
                        fontWeight: FontWeight.w800,
                        fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (m.income > 0) ...[
            ProgressBar(
              value: m.consumptionRate,
              color: m.consumptionRate > 1
                  ? AppColors.danger
                  : Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              _heroItem('الدخل', money(m.income, currency, decimals: false)),
              Container(
                  width: 1,
                  height: 34,
                  color: Colors.white.withValues(alpha: 0.18)),
              _heroItem('المصاريف', money(m.spent, currency, decimals: false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroItem(String label, String value) => Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 12, start: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12.5)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
              ),
            ],
          ),
        ),
      );
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? sub;
  final Color color;
  final VoidCallback? onTap;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 12),
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          SizedBox(
            height: 17,
            child: sub == null
                ? null
                : Text(sub!,
                    style: TextStyle(
                        color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final MonthStats m;
  final AppStore store;
  const _ProjectionCard({required this.m, required this.store});

  @override
  Widget build(BuildContext context) {
    final cur = store.currency;
    final limit =
        store.monthlyBudget > 0 ? store.monthlyBudget : m.income;
    final over = limit > 0 && m.projected > limit;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(over ? Icons.trending_up_rounded : Icons.insights_rounded,
              color: over ? AppColors.danger : AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المتوقع بنهاية الشهر: ${money(m.projected, cur, decimals: false)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 3),
                Text(
                  limit <= 0
                      ? 'حسب معدل صرفك اليومي الحالي'
                      : over
                          ? 'ستتجاوز ${store.monthlyBudget > 0 ? 'الميزانية' : 'الدخل'} بـ ${money(m.projected - limit, cur, decimals: false)}'
                          : 'ضمن ${store.monthlyBudget > 0 ? 'الميزانية' : 'الدخل'} — أحسنت',
                  style: TextStyle(
                      color: over ? AppColors.danger : AppColors.muted,
                      fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBreakdown extends StatefulWidget {
  final MonthStats m;
  final String currency;
  const _CategoryBreakdown({required this.m, required this.currency});

  @override
  State<_CategoryBreakdown> createState() => _CategoryBreakdownState();
}

class _CategoryBreakdownState extends State<_CategoryBreakdown> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.m.byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = widget.m.spent;
    final touchedEntry =
        _touched >= 0 && _touched < entries.length ? entries[_touched] : null;

    return AppCard(
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 62,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, resp) {
                        if (!event.isInterestedForInteractions ||
                            resp?.touchedSection == null) {
                          if (_touched != -1) setState(() => _touched = -1);
                          return;
                        }
                        setState(() => _touched =
                            resp!.touchedSection!.touchedSectionIndex);
                      },
                    ),
                    sections: [
                      for (var i = 0; i < entries.length; i++)
                        PieChartSectionData(
                          value: entries[i].value,
                          color: categoryById(entries[i].key).color,
                          radius: i == _touched ? 30 : 24,
                          showTitle: false,
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        touchedEntry == null
                            ? 'الإجمالي'
                            : categoryById(touchedEntry.key).name,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 2),
                    Text(
                        money(touchedEntry?.value ?? total, widget.currency,
                            decimals: false),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (final e in entries.take(6))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  CategoryAvatar(categoryById(e.key), size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(categoryById(e.key).name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                          ),
                          Text(money(e.value, widget.currency, decimals: false),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 14)),
                        ]),
                        const SizedBox(height: 6),
                        ProgressBar(
                          value: total > 0 ? e.value / total : 0,
                          color: categoryById(e.key).color,
                          height: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  final List<MonthStats> months;
  final String currency;
  const _TrendChart({required this.months, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxV = months.fold<double>(
        0, (m, s) => [m, s.spent, s.income].reduce((a, b) => a > b ? a : b));
    if (maxV == 0) {
      return const AppCard(
        child: SizedBox(
          height: 80,
          child: Center(
              child: Text('ستظهر هنا مقارنة الأشهر بعد إضافة البيانات',
                  style: TextStyle(color: AppColors.muted))),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxV * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.surface2,
                    getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                      money(rod.toY, currency, decimals: false),
                      const TextStyle(
                          color: AppColors.text, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(monthShort(months[v.toInt()].month),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 11)),
                      ),
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < months.length; i++)
                    BarChartGroupData(x: i, barsSpace: 4, barRods: [
                      BarChartRodData(
                        toY: months[i].spent,
                        width: 10,
                        color: AppColors.warning,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: months[i].saved > 0 ? months[i].saved : 0,
                        width: 10,
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend('المصاريف', AppColors.warning),
              SizedBox(width: 18),
              _Legend('المدّخر', AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final String text;
  final Color color;
  const _Legend(this.text, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ]);
}

class InsightCard extends StatelessWidget {
  final Insight i;
  final String? currency;
  const InsightCard(this.i, {super.key, this.currency});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: i.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(i.icon, color: i.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 5),
                Text(i.body,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 13.5, height: 1.55)),
                if (i.monthlySaving != null &&
                    i.monthlySaving! > 0 &&
                    currency != null) ...[
                  const SizedBox(height: 8),
                  Pill(
                      'توفير محتمل: ${money(i.monthlySaving!, currency!, decimals: false)} / شهر',
                      AppColors.primary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
