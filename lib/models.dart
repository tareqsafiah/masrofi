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

/// حركة في محفظة الدولار (موجب = إيداع، سالب = سحب)
class WalletTx {
  final String id;
  final double amount;
  final DateTime date;
  final String note;

  WalletTx({
    required this.id,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory WalletTx.fromJson(Map<String, dynamic> j) => WalletTx(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
      );
}

class Category {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool defaultEssential;

  const Category(
      this.id, this.name, this.icon, this.color, this.defaultEssential);
}

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
  Category('other', 'أخرى', Icons.more_horiz_rounded, Color(0xFFA3A3A3), true),
];

Category categoryById(String id) =>
    kCategories.firstWhere((c) => c.id == id, orElse: () => kCategories.last);
