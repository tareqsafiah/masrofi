import 'package:flutter/material.dart';

/// مصروف واحد
class Expense {
  final String id;
  final double amount;
  final String categoryId;
  final DateTime date;
  final String note;

  /// هل هو مصروف ضروري؟ (false = إنفاق غير ضروري / هدر)
  final bool essential;

  Expense({
    required this.id,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note = '',
    required this.essential,
  });

  Expense copyWith({
    double? amount,
    String? categoryId,
    DateTime? date,
    String? note,
    bool? essential,
  }) =>
      Expense(
        id: id,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        date: date ?? this.date,
        note: note ?? this.note,
        essential: essential ?? this.essential,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'cat': categoryId,
        'date': date.toIso8601String(),
        'note': note,
        'ess': essential,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        categoryId: j['cat'] as String,
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
        essential: (j['ess'] ?? true) as bool,
      );
}

/// حركة في المدخرات (دولار أو ذهب).
/// amount: الكمية (دولار أو غرام)، موجبة للشراء/الإيداع وسالبة للبيع/السحب.
/// total: المبلغ المدفوع/المقبوض بعملة المصاريف (إن كانت عملية شراء أو بيع).
class WalletTx {
  final String id;
  final double amount;
  final DateTime date;
  final String note;
  final String asset; // usd | g21 | g18
  final double? price; // سعر الوحدة بعملة المصاريف
  final double? total;

  WalletTx({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.asset = 'usd',
    this.price,
    this.total,
  });

  bool get isTrade => total != null;
  bool get isBuy => amount >= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        'asset': asset,
        if (price != null) 'price': price,
        if (total != null) 'total': total,
      };

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
        asset: (j['asset'] ?? 'usd') as String,
        price: (j['price'] as num?)?.toDouble(),
        total: (j['total'] as num?)?.toDouble(),
      );
}

/// دخل إضافي يُضاف للميزانية (مثل ثمن بيع دولار أو ذهب)
class IncomeEntry {
  final String id;
  final double amount;
  final DateTime date;
  final String note;
  final String? txId; // حركة المدخرات المرتبطة

  IncomeEntry({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
    this.txId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
        if (txId != null) 'tx': txId,
      };

  factory IncomeEntry.fromJson(Map<String, dynamic> j) => IncomeEntry(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
        txId: j['tx'] as String?,
      );
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool defaultEssential;
  final bool custom;

  const Category(
      this.id, this.name, this.icon, this.color, this.defaultEssential,
      {this.custom = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': kCategoryIcons.indexOf(icon),
        'color': kCategoryColors.indexOf(color),
        'ess': defaultEssential,
      };

  factory Category.fromJson(Map<String, dynamic> j) {
    final ii = (j['icon'] ?? 0) as int;
    final ci = (j['color'] ?? 0) as int;
    return Category(
      j['id'] as String,
      j['name'] as String,
      kCategoryIcons[ii.clamp(0, kCategoryIcons.length - 1)],
      kCategoryColors[ci.clamp(0, kCategoryColors.length - 1)],
      (j['ess'] ?? true) as bool,
      custom: true,
    );
  }
}

/// الأيقونات المتاحة للفئات الجديدة
const kCategoryIcons = <IconData>[
  Icons.label_rounded,
  Icons.local_cafe_rounded,
  Icons.local_gas_station_rounded,
  Icons.phone_iphone_rounded,
  Icons.wifi_rounded,
  Icons.electric_bolt_rounded,
  Icons.water_drop_rounded,
  Icons.child_care_rounded,
  Icons.pets_rounded,
  Icons.fitness_center_rounded,
  Icons.content_cut_rounded,
  Icons.checkroom_rounded,
  Icons.build_rounded,
  Icons.flight_rounded,
  Icons.local_taxi_rounded,
  Icons.medication_rounded,
  Icons.menu_book_rounded,
  Icons.volunteer_activism_rounded,
  Icons.family_restroom_rounded,
  Icons.weekend_rounded,
  Icons.devices_rounded,
  Icons.local_grocery_store_rounded,
  Icons.cake_rounded,
  Icons.sports_soccer_rounded,
];

const kCategoryColors = <Color>[
  Color(0xFF2ED6A0),
  Color(0xFF5B8CFF),
  Color(0xFFFFB547),
  Color(0xFFFF6B9A),
  Color(0xFF9C7CFF),
  Color(0xFF4FC3F7),
  Color(0xFFFF8A5B),
  Color(0xFFE879F9),
  Color(0xFFFACC15),
  Color(0xFF94A3B8),
];

const List<Category> kCategories = [
  Category('food', 'طعام ومشتريات', Icons.shopping_basket_rounded,
      Color(0xFF2ED6A0), true),
  Category('rent', 'سكن وإيجار', Icons.home_rounded, Color(0xFF5B8CFF), true),
  Category('bills', 'فواتير', Icons.receipt_long_rounded, Color(0xFF4FC3F7),
      true),
  Category('transport', 'مواصلات', Icons.directions_car_rounded,
      Color(0xFFFFB547), true),
  Category('health', 'صحة', Icons.favorite_rounded, Color(0xFFFF6B9A), true),
  Category('education', 'تعليم', Icons.school_rounded, Color(0xFF9C7CFF), true),
  Category('restaurants', 'مطاعم وكافيهات', Icons.restaurant_rounded,
      Color(0xFFFF8A5B), false),
  Category('shopping', 'تسوق وملابس', Icons.shopping_bag_rounded,
      Color(0xFFE879F9), false),
  Category('entertainment', 'ترفيه', Icons.sports_esports_rounded,
      Color(0xFFFACC15), false),
  Category('subscriptions', 'اشتراكات', Icons.subscriptions_rounded,
      Color(0xFF38BDF8), false),
  Category('smoking', 'تدخين', Icons.smoking_rooms_rounded, Color(0xFF94A3B8),
      false),
  Category('gifts', 'هدايا ومناسبات', Icons.card_giftcard_rounded,
      Color(0xFFF472B6), false),
  Category('debt', 'سداد ديون', Icons.account_balance_rounded,
      Color(0xFFF87171), true),
  Category('other', 'أخرى', Icons.more_horiz_rounded, Color(0xFFA3A3A3), true),
];

/// الفئات التي أضافها المستخدم (يملؤها AppStore)
List<Category> customCategories = [];

/// كل الفئات: الثابتة ثم المضافة، و"أخرى" دائماً في الآخر
List<Category> get allCategories => [
      ...kCategories.where((c) => c.id != 'other'),
      ...customCategories,
      kCategories.last,
    ];

Category categoryById(String id) =>
    allCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.last);

/// دين على المستخدم (بالليرة/عملة المصاريف أو بالدولار)
class Debt {
  final String id;
  final String name; // لمن الدين أو وصفه
  final bool usd; // true = بالدولار، false = بعملة المصاريف
  final double amount; // أصل الدين (أو الرصيد عند الإضافة)
  final double rate; // الفائدة السنوية %
  final double minPayment; // القسط الشهري المتفق عليه (0 = لا يوجد)
  final DateTime date;
  final DateTime? due; // موعد السداد النهائي (اختياري)
  final String note;

  Debt({
    required this.id,
    required this.name,
    required this.usd,
    required this.amount,
    this.rate = 0,
    this.minPayment = 0,
    required this.date,
    this.due,
    this.note = '',
  });

  Debt copyWith({
    String? name,
    double? amount,
    double? rate,
    double? minPayment,
    DateTime? due,
    bool clearDue = false,
    String? note,
  }) =>
      Debt(
        id: id,
        name: name ?? this.name,
        usd: usd,
        amount: amount ?? this.amount,
        rate: rate ?? this.rate,
        minPayment: minPayment ?? this.minPayment,
        date: date,
        due: clearDue ? null : (due ?? this.due),
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'usd': usd,
        'amount': amount,
        'rate': rate,
        'min': minPayment,
        'date': date.toIso8601String(),
        if (due != null) 'due': due!.toIso8601String(),
        'note': note,
      };

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'] as String,
        name: j['name'] as String,
        usd: (j['usd'] ?? false) as bool,
        amount: (j['amount'] as num).toDouble(),
        rate: ((j['rate'] ?? 0) as num).toDouble(),
        minPayment: ((j['min'] ?? 0) as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        due: j['due'] == null ? null : DateTime.parse(j['due'] as String),
        note: (j['note'] ?? '') as String,
      );
}

/// دفعة سداد لدين. linkId: المصروف أو حركة المحفظة الناتجة عنها
class DebtPayment {
  final String id;
  final String debtId;
  final double amount; // بعملة الدين
  final DateTime date;
  final String? linkId;
  final String source; // budget | wallet | none

  DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.linkId,
    this.source = 'budget',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'debt': debtId,
        'amount': amount,
        'date': date.toIso8601String(),
        if (linkId != null) 'link': linkId,
        'src': source,
      };

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        id: j['id'] as String,
        debtId: j['debt'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        linkId: j['link'] as String?,
        source: (j['src'] ?? 'budget') as String,
      );
}
