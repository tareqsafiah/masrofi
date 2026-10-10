import 'package:flutter_test/flutter_test.dart';
import 'package:masrofi/cloud.dart';
import 'package:masrofi/debt_plan.dart';
import 'package:masrofi/format.dart';
import 'package:masrofi/widgets.dart';

void main() {
  test('parseAmount يدعم الأرقام العربية والفواصل', () {
    expect(parseAmount('١٢٥'), 125);
    expect(parseAmount('1,250.5'), 1250.5);
    expect(parseAmount('abc'), isNull);
  });

  test('money يعرض الدولار بشكل صحيح', () {
    expect(money(1500, '\$', decimals: false), '\$1,500');
    expect(money(-20, '\$', decimals: false), '-\$20');
  });

  group('خطط سداد الديون', () {
    const debts = [
      PlanDebt('card', 'بطاقة', 3000, 24, 90),
      PlanDebt('car', 'سيارة', 8000, 6, 250),
      PlanDebt('friend', 'صديق', 1000, 0, 0),
    ];

    test('كرة الثلج تبدأ بالأصغر', () {
      final r = simulatePlan(debts, 200, DebtStrategy.snowball);
      expect(r.feasible, isTrue);
      expect(r.order.first.id, 'friend');
      expect(r.months, 25);
    });

    test('الانهيار الجليدي يبدأ بالأعلى فائدة ويوفّر فوائد', () {
      final a = simulatePlan(debts, 200, DebtStrategy.avalanche);
      final s = simulatePlan(debts, 200, DebtStrategy.snowball);
      expect(a.order.first.id, 'card');
      expect(a.months, 24);
      expect(a.totalInterest, lessThan(s.totalInterest));
    });

    test('دفعة لا تغطي الفائدة = خطة غير ممكنة', () {
      final r = simulatePlan(
          const [PlanDebt('x', 'x', 10000, 36, 100)], 0, DebtStrategy.avalanche);
      expect(r.feasible, isFalse);
    });

    test('بدون أقساط ولا مبلغ إضافي', () {
      final r = simulatePlan(
          const [PlanDebt('x', 'x', 500, 0, 0)], 0, DebtStrategy.snowball);
      expect(r.feasible, isFalse);
      expect(r.monthlyBudget, 0);
    });
  });

  group('الحسابات والتشفير', () {
    test('فتح الخزنة بكلمة المرور الصحيحة فقط', () async {
      final enc = await Vault.seal('secret-123', {'token': 'abc'});
      expect((await Vault.open('secret-123', enc))?['token'], 'abc');
      expect(await Vault.open('wrong-pass', enc), isNull);
    });

    test('مسار الحساب لا يتأثر بحالة الأحرف والمسافات', () async {
      final a = await Accounts.path('Tareq');
      expect(a, await Accounts.path(' tareq '));
      expect(a, isNot(await Accounts.path('other')));
      expect(a, startsWith('accounts/'));
      expect(a.contains('tareq'), isFalse);
    });

    test('فك ملف الحساب يعيد إعدادات الاتصال', () async {
      final enc = await Vault.seal('pass-1234', {
        'username': 'tareq',
        'owner': 'o',
        'repo': 'r',
        'token': 't',
        'dataPass': 'd',
      });
      final c = await Accounts.unlock(enc, 'tareq', 'pass-1234');
      expect(c?.token, 't');
      expect(c?.password, 'd');
      expect(c?.username, 'tareq');
      expect(await Accounts.unlock(enc, 'tareq', 'nope-nope'), isNull);
    });
  });
}
