import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'categories.dart';

Future<void> openExpenseSheet(BuildContext context, {Expense? existing}) {
  return showAppSheet(context, ExpenseForm(existing: existing));
}

class ExpenseForm extends StatefulWidget {
  final Expense? existing;
  const ExpenseForm({super.key, this.existing});

  @override
  State<ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<ExpenseForm> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _cat;
  late bool _essential;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e == null ? '' : e.amount.toString().replaceAll(RegExp(r'\.0$'), ''));
    _note = TextEditingController(text: e?.note ?? '');
    _cat = e?.categoryId ?? 'food';
    _essential = e?.essential ?? categoryById(_cat).defaultEssential;
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseAmount(_amount.text);
    if (v == null || v <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً')));
      return;
    }
    final s = context.read<AppStore>();
    if (widget.existing == null) {
      s.addExpense(Expense(
        id: s.newId(),
        amount: v,
        categoryId: _cat,
        date: _date,
        note: _note.text.trim(),
        essential: _essential,
      ));
    } else {
      s.updateExpense(widget.existing!.copyWith(
        amount: v,
        categoryId: _cat,
        date: _date,
        note: _note.text.trim(),
        essential: _essential,
      ));
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day,
          _date.hour, _date.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppStore>();
    final editing = widget.existing != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(editing ? 'تعديل المصروف' : 'مصروف جديد',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            if (editing)
              IconButton(
                onPressed: () {
                  s.deleteExpense(widget.existing!.id);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AmountField(
            controller: _amount,
            label: 'المبلغ',
            suffix: s.currency,
            autofocus: !editing),
        const SizedBox(height: 18),
        const Text('الفئة',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in allCategories)
              _CatChip(
                cat: c,
                selected: c.id == _cat,
                onTap: () => setState(() {
                  _cat = c.id;
                  _essential = c.defaultEssential;
                }),
              ),
            ActionChip(
              avatar: const Icon(Icons.add_rounded,
                  size: 18, color: AppColors.primary),
              label: const Text('فئة جديدة'),
              backgroundColor: AppColors.surface2,
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              onPressed: () async {
                final id = await openNewCategorySheet(context);
                if (id != null && mounted) {
                  setState(() {
                    _cat = id;
                    _essential = categoryById(id).defaultEssential;
                  });
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 18),
        _EssentialToggle(
          value: _essential,
          onChanged: (v) => setState(() => _essential = v),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'ملاحظة (اختياري)',
            hintText: 'مثال: قهوة مع الأصدقاء',
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded,
                    color: AppColors.muted, size: 20),
                const SizedBox(width: 10),
                Text(dayLabel(_date), style: const TextStyle(fontSize: 15)),
                const Spacer(),
                const Text('تغيير',
                    style: TextStyle(color: AppColors.primary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'حفظ التعديلات' : 'إضافة المصروف'),
        ),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  final Category cat;
  final bool selected;
  final VoidCallback onTap;
  const _CatChip(
      {required this.cat, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? cat.color.withValues(alpha: 0.18)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: selected ? cat.color : Colors.transparent, width: 1.3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icon,
                size: 17, color: selected ? cat.color : AppColors.muted),
            const SizedBox(width: 6),
            Text(cat.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.muted,
                )),
          ],
        ),
      ),
    );
  }
}

class _EssentialToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _EssentialToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget opt(String label, IconData icon, bool v, Color color) {
      final sel = value == v;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(v);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: sel ? color.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: sel ? color : AppColors.muted),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: sel ? color : AppColors.muted,
                    )),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        opt('ضروري', Icons.check_circle_rounded, true, AppColors.primary),
        opt('غير ضروري', Icons.local_fire_department_rounded, false,
            AppColors.warning),
      ]),
    );
  }
}
