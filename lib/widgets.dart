import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'format.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.gradient,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? AppColors.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        border: gradient == null ? Border.all(color: AppColors.border) : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: card,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.chevron_right_rounded, () => s.shiftMonth(-1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(monthName(s.selectedMonth),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          _btn(Icons.chevron_left_rounded,
              s.isCurrentMonth ? null : () => s.shiftMonth(1)),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) => IconButton(
        visualDensity: VisualDensity.compact,
        onPressed: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        icon: Icon(icon,
            color: onTap == null ? AppColors.border : AppColors.text),
      );
}

class CategoryAvatar extends StatelessWidget {
  final Category cat;
  final double size;
  const CategoryAvatar(this.cat, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(cat.icon, color: cat.color, size: size * 0.5),
    );
  }
}

class ExpenseTile extends StatelessWidget {
  final Expense e;
  final VoidCallback? onTap;
  const ExpenseTile(this.e, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final cat = categoryById(e.categoryId);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            CategoryAvatar(cat),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.note.isEmpty ? cat.name : e.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                            e.note.isEmpty
                                ? dayLabel(e.date)
                                : '${cat.name} · ${dayLabel(e.date)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.muted)),
                      ),
                      if (!e.essential) ...[
                        const SizedBox(width: 6),
                        const Pill('غير ضروري', AppColors.warning),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(money(-e.amount, s.currency),
                style: const TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;
  const Pill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10.5, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 34, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          Text(title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.5)),
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const ProgressBar(
      {super.key, required this.value, required this.color, this.height = 8});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Stack(
        children: [
          Container(height: height, color: Colors.white.withValues(alpha: 0.08)),
          FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// حقل إدخال رقمي يقبل الفواصل العشرية
class AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final bool autofocus;
  const AmountField(
      {super.key,
      required this.controller,
      required this.label,
      this.suffix,
      this.autofocus = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,٠-٩]')),
      ],
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }
}

/// يحوّل نص المبلغ (مع دعم الأرقام العربية) إلى رقم
double? parseAmount(String raw) {
  const ar = '٠١٢٣٤٥٦٧٨٩';
  var t = raw.trim();
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(ar[i], '$i');
  }
  t = t.replaceAll(',', '');
  return double.tryParse(t);
}

Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}
