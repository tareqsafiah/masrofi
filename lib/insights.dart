import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

enum InsightLevel { good, info, warn, bad }

class Insight {
  final InsightLevel level;
  final String title;
  final String body;
  final IconData icon;

  /// مبلغ التوفير الشهري المتوقع إن طُبّقت النصيحة (اختياري)
  final double? monthlySaving;

  const Insight(this.level, this.title, this.body, this.icon,
      {this.monthlySaving});

  Color get color => switch (level) {
        InsightLevel.good => AppColors.primary,
        InsightLevel.info => AppColors.info,
        InsightLevel.warn => AppColors.warning,
        InsightLevel.bad => AppColors.danger,
      };
}

/// يولّد نصائح مخصّصة بناءً على بيانات الشهر المختار
List<Insight> buildInsights(AppStore s) {
  final out = <Insight>[];
  final m = s.current;
  final prev = s.previous;
  final cur = s.currency;
  String f(double v) => money(v, cur, decimals: false);

  if (m.count == 0) {
    out.add(const Insight(
      InsightLevel.info,
      'ابدأ بتسجيل مصاريفك',
      'سجّل كل مصروف مهما كان صغيراً لمدة شهر كامل. الوعي بأين يذهب المال هو أول وأقوى خطوة لتقليله.',
      Icons.edit_note_rounded,
    ));
    return out;
  }

  // ---- معدل الادخار ----
  if (m.income > 0) {
    if (m.saved < 0) {
      out.add(Insight(
        InsightLevel.bad,
        'مصاريفك تجاوزت دخلك',
        'صرفت ${f(m.spent)} مقابل دخل ${f(m.income)}، أي بعجز ${f(-m.saved)}. أوقف فوراً المصاريف غير الضرورية حتى نهاية الشهر.',
        Icons.warning_amber_rounded,
      ));
    } else if (m.savingsRate < 0.10) {
      final target = m.income * 0.20 - m.saved;
      out.add(Insight(
        InsightLevel.warn,
        'معدل ادخارك ${pct(m.savingsRate)} فقط',
        'الهدف الصحي هو ادخار 20% على الأقل من الدخل. تحتاج لتوفير ${f(target)} إضافية شهرياً للوصول إليه.',
        Icons.trending_down_rounded,
        monthlySaving: target,
      ));
    } else if (m.savingsRate >= 0.20) {
      out.add(Insight(
        InsightLevel.good,
        'ممتاز! تدّخر ${pct(m.savingsRate)} من دخلك',
        'أنت فوق المعدل الموصى به (20%). حوّل المبلغ المدّخر إلى محفظة الدولار مباشرة حتى لا تصرفه.',
        Icons.emoji_events_rounded,
      ));
    } else {
      out.add(Insight(
        InsightLevel.info,
        'معدل ادخارك ${pct(m.savingsRate)}',
        'أنت قريب من الهدف. خفّض الإنفاق غير الضروري قليلاً لتصل إلى 20%.',
        Icons.savings_rounded,
      ));
    }
  } else {
    out.add(const Insight(
      InsightLevel.info,
      'أضف دخلك الشهري',
      'من الإعدادات أدخل دخلك الشهري لنحسب معدل الادخار والاستهلاك بدقة.',
      Icons.account_balance_wallet_rounded,
    ));
  }

  // ---- قاعدة 50/30/20 ----
  if (m.income > 0) {
    final needs = m.essential / m.income;
    final wants = m.waste / m.income;
    if (wants > 0.30) {
      final excess = m.waste - m.income * 0.30;
      out.add(Insight(
        InsightLevel.warn,
        'الكماليات تأخذ ${pct(wants)} من دخلك',
        'حسب قاعدة 50/30/20 يجب ألا تتجاوز الكماليات 30%. تخفيضها يوفّر ${f(excess)} شهرياً.',
        Icons.pie_chart_rounded,
        monthlySaving: excess,
      ));
    }
    if (needs > 0.60) {
      out.add(Insight(
        InsightLevel.info,
        'الضروريات ${pct(needs)} من دخلك',
        'المصاريف الأساسية مرتفعة. راجع الفواتير والإيجار والمواصلات: هل يوجد عرض أرخص أو باقة أنسب؟',
        Icons.home_work_rounded,
      ));
    }
  }

  // ---- الهدر ----
  if (m.wasteRatio > 0.25) {
    out.add(Insight(
      InsightLevel.warn,
      '${pct(m.wasteRatio)} من مصاريفك غير ضرورية',
      'لو خفّضت الإنفاق غير الضروري للنصف ستوفر ${f(m.waste / 2)} شهرياً، أي ${f(m.waste * 6)} سنوياً.',
      Icons.local_fire_department_rounded,
      monthlySaving: m.waste / 2,
    ));
  }

  // ---- قواعد حسب الفئة ----
  double share(String id) => m.spent > 0 ? (m.byCategory[id] ?? 0) / m.spent : 0;
  double amt(String id) => m.byCategory[id] ?? 0;

  if (share('restaurants') > 0.12) {
    out.add(Insight(
      InsightLevel.warn,
      'المطاعم والكافيهات ${pct(share('restaurants'))} من مصاريفك',
      'حضّر وجباتك وقهوتك في البيت 4 أيام من أصل 7 وستوفر قرابة ${f(amt('restaurants') * 0.55)} شهرياً.',
      Icons.restaurant_rounded,
      monthlySaving: amt('restaurants') * 0.55,
    ));
  }
  if (amt('subscriptions') > 0) {
    out.add(Insight(
      InsightLevel.info,
      'راجع اشتراكاتك',
      'تدفع ${f(amt('subscriptions'))} على الاشتراكات هذا الشهر. ألغِ أي اشتراك لم تستخدمه في آخر أسبوعين.',
      Icons.subscriptions_rounded,
      monthlySaving: amt('subscriptions') * 0.4,
    ));
  }
  if (amt('smoking') > 0) {
    out.add(Insight(
      InsightLevel.bad,
      'التدخين يكلّفك ${f(amt('smoking') * 12)} سنوياً',
      'تقليل التدخين للنصف يوفّر ${f(amt('smoking') / 2)} شهرياً، إضافة لفائدته الصحية الكبيرة.',
      Icons.smoking_rooms_rounded,
      monthlySaving: amt('smoking') / 2,
    ));
  }
  if (share('shopping') > 0.15) {
    out.add(Insight(
      InsightLevel.warn,
      'التسوق ${pct(share('shopping'))} من مصاريفك',
      'طبّق قاعدة الـ 48 ساعة: أي شيء غير ضروري أضفه لقائمة وانتظر يومين قبل شرائه. معظم الرغبات تختفي.',
      Icons.shopping_bag_rounded,
      monthlySaving: amt('shopping') * 0.35,
    ));
  }
  if (share('entertainment') > 0.12) {
    out.add(Insight(
      InsightLevel.info,
      'الترفيه ${pct(share('entertainment'))} من مصاريفك',
      'حدّد مبلغاً ثابتاً للترفيه أسبوعياً، وابحث عن بدائل مجانية: المشي، الحدائق، الأمسيات مع الأصدقاء في البيت.',
      Icons.sports_esports_rounded,
      monthlySaving: amt('entertainment') * 0.3,
    ));
  }

  // ---- مقارنة بالشهر السابق ----
  if (prev.spent > 0 && m.daysCounted > 0) {
    final now = DateTime.now();
    final isCur = s.isCurrentMonth;
    final compare = isCur ? m.projected : m.spent;
    final change = (compare - prev.spent) / prev.spent;
    if (change > 0.10) {
      out.add(Insight(
        InsightLevel.warn,
        isCur
            ? 'بهذا المعدل ستصرف أكثر بـ ${pct(change)} من الشهر الماضي'
            : 'صرفت أكثر بـ ${pct(change)} من الشهر السابق',
        'الشهر السابق صرفت ${f(prev.spent)}${isCur ? '، والمتوقع هذا الشهر ${f(m.projected)} (يوم ${now.day})' : ''}.',
        Icons.show_chart_rounded,
      ));
    } else if (change < -0.05) {
      out.add(Insight(
        InsightLevel.good,
        'مصاريفك أقل بـ ${pct(-change)} من الشهر السابق',
        'استمر! كل تخفيض صغير يتراكم إلى مبلغ كبير على مدار السنة.',
        Icons.thumb_up_alt_rounded,
      ));
    }
  }

  // ---- الميزانية ----
  if (s.monthlyBudget > 0 && s.isCurrentMonth) {
    final left = s.monthlyBudget - m.spent;
    final daysLeft = daysInMonth(m.month) - DateTime.now().day + 1;
    if (left <= 0) {
      out.add(Insight(
        InsightLevel.bad,
        'تجاوزت ميزانية الشهر',
        'تخطيت الميزانية بـ ${f(-left)}. اكتفِ بالضروريات حتى بداية الشهر القادم.',
        Icons.block_rounded,
      ));
    } else {
      out.add(Insight(
        m.projected > s.monthlyBudget ? InsightLevel.warn : InsightLevel.good,
        'متبقٍّ ${f(left)} من الميزانية',
        'يمكنك صرف ${f(left / daysLeft)} يومياً حتى نهاية الشهر لتبقى ضمن الميزانية.',
        Icons.calendar_month_rounded,
      ));
    }
  }

  // ---- صندوق الطوارئ ----
  final avg = s.avgMonthlySpend;
  final sv = s.totalSavingsValue ??
      (s.currency == '\$' ? s.walletBalance : null);
  if (avg > 0 && sv != null) {
    final months = sv / avg;
    if (months < 3) {
      out.add(Insight(
        InsightLevel.info,
        'مدّخراتك تغطي ${months.toStringAsFixed(1)} شهر من المصاريف',
        'الهدف الآمن هو 3–6 أشهر. تحتاج ${f(avg * 3 - sv)} إضافية للوصول لـ 3 أشهر.',
        Icons.shield_rounded,
      ));
    } else {
      out.add(Insight(
        InsightLevel.good,
        'لديك صندوق طوارئ يكفي ${months.toStringAsFixed(1)} أشهر',
        'وضع مالي آمن. يمكنك التفكير في استثمار ما يزيد عن 6 أشهر من المصاريف.',
        Icons.shield_rounded,
      ));
    }
  }

  // ---- الديون ----
  final debtTotal = s.totalDebtLocal;
  if (s.activeDebts.isNotEmpty && debtTotal != null) {
    final mins = s.monthlyMinPaymentsLocal ?? 0;
    final dti = m.income > 0 ? mins / m.income : 0.0;
    if (dti > 0.36) {
      out.add(Insight(
        InsightLevel.bad,
        'أقساط الديون ${pct(dti)} من دخلك',
        'هذه نسبة خطرة. لا تأخذ أي دين جديد، ووجّه كل فائض للسداد حسب خطة الديون.',
        Icons.account_balance_rounded,
      ));
    } else {
      out.add(Insight(
        InsightLevel.warn,
        'عليك ديون بقيمة ${f(debtTotal)}',
        'افتح خطة السداد في شاشة الديون لتعرف أسرع طريقة للتخلص منها وموعد تحررك.',
        Icons.account_balance_rounded,
      ));
    }
    if (s.activeDebts.any((d) => d.usd) && s.isSyp) {
      out.add(const Insight(
        InsightLevel.info,
        'انتبه للديون بالدولار',
        'كل ارتفاع في سعر الدولار يزيد قيمة دينك بالليرة. سدّدها أولاً إن أمكن، أو من مدخراتك بالدولار.',
        Icons.currency_exchange_rounded,
      ));
    }
  }

  // ترتيب: الأخطر أولاً
  out.sort((a, b) => b.level.index.compareTo(a.level.index));
  return out;
}

class GeneralTip {
  final String title;
  final String body;
  final IconData icon;
  const GeneralTip(this.title, this.body, this.icon);
}

const kSpendTips = [
  GeneralTip('ادفع لنفسك أولاً',
      'فور استلام الراتب حوّل نسبة الادخار إلى المحفظة قبل أي مصروف، ثم عِش على الباقي.',
      Icons.bolt_rounded),
  GeneralTip('قاعدة 48 ساعة',
      'لأي شراء غير ضروري انتظر يومين. إذا بقيت تريده بعدها فاشترِه بدون شعور بالذنب.',
      Icons.timer_rounded),
  GeneralTip('تسوّق بقائمة',
      'اكتب قائمة المشتريات قبل الخروج، ولا تتسوق وأنت جائع. هذا وحده يخفض فاتورة البقالة 15–20%.',
      Icons.checklist_rounded),
  GeneralTip('احسب السعر بساعات العمل',
      'قبل أي شراء اسأل: كم ساعة عمل يكلفني هذا؟ يجعل القرار أوضح بكثير.',
      Icons.hourglass_bottom_rounded),
  GeneralTip('الكاش للمصاريف اليومية',
      'الدفع النقدي يجعلك تشعر بالمال يخرج، فتصرف أقل مقارنة بالبطاقة.',
      Icons.payments_rounded),
  GeneralTip('ميزانية ظرف لكل فئة',
      'خصص مبلغاً ثابتاً للمطاعم والترفيه أسبوعياً، وعندما ينتهي تتوقف.',
      Icons.mail_rounded),
  GeneralTip('ألغِ الاشتراكات المنسية',
      'راجع اشتراكاتك كل 3 أشهر، وألغِ كل ما لم تستخدمه مؤخراً.',
      Icons.subscriptions_rounded),
];

const kSaveTips = [
  GeneralTip('أتمِت الادخار',
      'حدد يوماً ثابتاً كل شهر (يوم الراتب) لتحويل مبلغ ثابت إلى محفظة الدولار.',
      Icons.autorenew_rounded),
  GeneralTip('ادّخر الزيادات',
      'أي زيادة في الراتب أو دخل إضافي، ادّخر نصفها على الأقل قبل أن تعتاد عليها.',
      Icons.trending_up_rounded),
  GeneralTip('تحدّي الـ 52 أسبوع',
      'ادّخر 1\$ في الأسبوع الأول، 2\$ في الثاني... وستجمع 1378\$ في سنة.',
      Icons.flag_rounded),
  GeneralTip('صندوق طوارئ أولاً',
      'اجمع ما يغطي 3–6 أشهر من المصاريف قبل أي استثمار أو شراء كبير.',
      Icons.shield_rounded),
  GeneralTip('ادّخر الفكّة',
      'كل مبلغ صغير يتبقى معك آخر اليوم ضعه جانباً. يتحول لمبلغ محترم آخر الشهر.',
      Icons.savings_rounded),
  GeneralTip('مصدر دخل إضافي',
      'مهارة واحدة (تصميم، برمجة، ترجمة، تدريس) يمكن أن تضيف دخلاً تدّخره بالكامل.',
      Icons.work_rounded),
];

/// أعلى الفئات غير الضرورية لهذا الشهر
List<MapEntry<Category, double>> topWasteCategories(AppStore s) {
  final map = <String, double>{};
  for (final e in s.expensesIn(s.selectedMonth)) {
    if (!e.essential) map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amount;
  }
  final list = map.entries
      .map((e) => MapEntry(categoryById(e.key), e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return list;
}
