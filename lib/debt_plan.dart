/// محرك خطط سداد الديون (كرة الثلج / الانهيار الجليدي)
enum DebtStrategy { snowball, avalanche }

class PlanDebt {
  final String id;
  final String name;
  final double balance; // بعملة موحّدة
  final double rate; // فائدة سنوية %
  final double minPayment;

  const PlanDebt(this.id, this.name, this.balance, this.rate, this.minPayment);
}

class PayoffStep {
  final String id;
  final String name;
  final int month; // رقم الشهر الذي يُسدَّد فيه بالكامل (1 = الشهر القادم)
  const PayoffStep(this.id, this.name, this.month);
}

class PlanResult {
  final bool feasible;
  final int months;
  final double totalInterest;
  final double totalPaid;
  final double monthlyBudget;
  final List<PayoffStep> order;

  const PlanResult({
    required this.feasible,
    required this.months,
    required this.totalInterest,
    required this.totalPaid,
    required this.monthlyBudget,
    required this.order,
  });
}

/// يحاكي السداد شهراً بشهر. مجموع الدفعة الشهرية ثابت:
/// الأقساط الدنيا + المبلغ الإضافي، وعند انتهاء دين ينتقل قسطه للدين التالي.
PlanResult simulatePlan(List<PlanDebt> debts, double extra, DebtStrategy s,
    {int maxMonths = 600}) {
  final active = debts.where((d) => d.balance > 0.005).toList();
  final bal = {for (final d in active) d.id: d.balance};
  final budget =
      active.fold<double>(0, (a, d) => a + d.minPayment) + (extra > 0 ? extra : 0);
  if (active.isEmpty) {
    return const PlanResult(
        feasible: true,
        months: 0,
        totalInterest: 0,
        totalPaid: 0,
        monthlyBudget: 0,
        order: []);
  }
  if (budget <= 0) {
    return PlanResult(
        feasible: false,
        months: 0,
        totalInterest: 0,
        totalPaid: 0,
        monthlyBudget: 0,
        order: const []);
  }

  int byStrategy(PlanDebt a, PlanDebt b) {
    if (s == DebtStrategy.avalanche) {
      final c = b.rate.compareTo(a.rate);
      if (c != 0) return c;
    }
    final c = bal[a.id]!.compareTo(bal[b.id]!);
    return c != 0 ? c : b.rate.compareTo(a.rate);
  }

  double interest = 0, paid = 0;
  final order = <PayoffStep>[];
  var month = 0;
  while (bal.values.any((v) => v > 0.005) && month < maxMonths) {
    month++;
    // الفائدة الشهرية
    for (final d in active) {
      final b = bal[d.id]!;
      if (b > 0.005 && d.rate > 0) {
        final i = b * d.rate / 100 / 12;
        bal[d.id] = b + i;
        interest += i;
      }
    }
    var left = budget;
    // الأقساط الدنيا أولاً
    for (final d in active) {
      final b = bal[d.id]!;
      if (b <= 0.005) continue;
      final p = d.minPayment < b ? d.minPayment : b;
      bal[d.id] = b - p;
      left -= p;
      paid += p;
    }
    // الباقي للدين المستهدف حسب الاستراتيجية
    final targets = active.where((d) => bal[d.id]! > 0.005).toList()
      ..sort(byStrategy);
    for (final d in targets) {
      if (left <= 0.005) break;
      final b = bal[d.id]!;
      final p = left < b ? left : b;
      bal[d.id] = b - p;
      left -= p;
      paid += p;
    }
    for (final d in active) {
      if (bal[d.id]! <= 0.005 && !order.any((o) => o.id == d.id)) {
        bal[d.id] = 0;
        order.add(PayoffStep(d.id, d.name, month));
      }
    }
  }
  final done = bal.values.every((v) => v <= 0.005);
  return PlanResult(
    feasible: done,
    months: month,
    totalInterest: interest,
    totalPaid: paid,
    monthlyBudget: budget,
    order: order,
  );
}
