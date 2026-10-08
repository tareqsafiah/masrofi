import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../insights.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dashboard.dart';

class TipsScreen extends StatefulWidget {
  const TipsScreen({super.key});

  @override
  State<TipsScreen> createState() => _TipsScreenState();
}

class _TipsScreenState extends State<TipsScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final insights = buildInsights(s);
    final potential = insights
        .where((i) => i.monthlySaving != null && i.monthlySaving! > 0)
        .fold<double>(0, (a, i) => a + i.monthlySaving!);
    final m = s.current;

    return CustomScrollView(
      slivers: [
        const SliverAppBar(
            pinned: true, toolbarHeight: 64, title: Text('اقتراحات')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(children: [
            _Segmented(
              index: _tab,
              labels: const ['لك أنت', 'تقليل الصرف', 'زيادة الادخار'],
              onChanged: (i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              if (potential > 0)
                AppCard(
                  padding: const EdgeInsets.all(20),
                  gradient: const LinearGradient(
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                    colors: [Color(0xFF14A37A), Color(0xFF123A45)],
                  ),
                  child: Row(children: [
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('بتطبيق هذه النصائح يمكنك توفير',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                              '${money(potential, s.currency, decimals: false)} شهرياً',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              '≈ ${money(potential * 12, s.currency, decimals: false)} في السنة',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                  ]),
                ),
              if (m.income > 0 && m.count > 0) ...[
                const SectionTitle('قاعدة 50 / 30 / 20'),
                _RuleCard(store: s),
              ],
              SectionTitle('تحليل ${monthName(s.selectedMonth)}'),
              for (final i in insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InsightCard(i, currency: s.currency),
                ),
            ] else
              for (final t in (_tab == 1 ? kSpendTips : kSaveTips))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (_tab == 1
                                    ? AppColors.warning
                                    : AppColors.primary)
                                .withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(t.icon,
                              size: 21,
                              color: _tab == 1
                                  ? AppColors.warning
                                  : AppColors.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              const SizedBox(height: 5),
                              Text(t.body,
                                  style: const TextStyle(
                                      color: AppColors.muted,
                                      fontSize: 13.5,
                                      height: 1.55)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ]),
        ),
      ],
    );
  }
}

class _RuleCard extends StatelessWidget {
  final AppStore store;
  const _RuleCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final m = store.current;
    final inc = m.income;
    final rows = [
      ('ضروريات', m.essential / inc, 0.50, AppColors.info, true),
      ('كماليات', m.waste / inc, 0.30, AppColors.warning, true),
      ('ادخار', m.saved / inc, 0.20, AppColors.primary, false),
    ];
    return AppCard(
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(r.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${pct(r.$2 < 0 ? 0.0 : r.$2)} ',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: _ok(r) ? r.$4 : AppColors.danger)),
                    Text('/ الهدف ${pct(r.$3)}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12.5)),
                  ]),
                  const SizedBox(height: 7),
                  ProgressBar(
                      value: r.$2 < 0 ? 0.0 : r.$2,
                      color: _ok(r) ? r.$4 : AppColors.danger),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// للضروريات والكماليات: الأقل أفضل، للادخار: الأعلى أفضل
  bool _ok((String, double, double, Color, bool) r) =>
      r.$5 ? r.$2 <= r.$3 : r.$2 >= r.$3;
}

class _Segmented extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;
  const _Segmented(
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
              onTap: () => onChanged(i),
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
