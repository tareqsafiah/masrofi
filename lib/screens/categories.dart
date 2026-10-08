import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// إدارة فئات المصاريف: الثابتة + التي يضيفها المستخدم
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final custom = customCategories;
    return Scaffold(
      appBar: AppBar(title: const Text('فئات المصاريف')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openNewCategorySheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF04140E),
        icon: const Icon(Icons.add_rounded),
        label: const Text('فئة جديدة',
            style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          SectionTitle('فئاتك (${custom.length})'),
          if (custom.isEmpty)
            const EmptyState(
              icon: Icons.category_rounded,
              title: 'لم تضف فئات بعد',
              subtitle: 'أضف فئات تناسب مصاريفك، مثل: بنزين، إنترنت، أطفال...',
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(children: [
                for (final c in custom)
                  ListTile(
                    leading: CategoryAvatar(c, size: 40),
                    title: Text(c.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                        '${c.defaultEssential ? 'ضروري' : 'غير ضروري'} · ${s.expenseCountFor(c.id)} مصروف',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12.5)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger),
                      onPressed: () => _confirmDelete(context, s, c),
                    ),
                  ),
              ]),
            ),
          const SectionTitle('الفئات الأساسية'),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kCategories)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(c.icon, size: 16, color: c.color),
                      const SizedBox(width: 6),
                      Text(c.name,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.muted)),
                    ]),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text('الفئات الأساسية ثابتة ولا يمكن حذفها.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, AppStore s, Category c) async {
    final n = s.expenseCountFor(c.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('حذف فئة "${c.name}"؟'),
        content: Text(n == 0
            ? 'لا توجد مصاريف مسجّلة في هذه الفئة.'
            : 'سيتم نقل $n مصروف إلى فئة "أخرى"، ولن يُحذف أي مصروف.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('إلغاء')),
          TextButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok == true) s.deleteCategory(c.id);
  }
}

/// نافذة إضافة فئة. تعيد معرّف الفئة الجديدة.
Future<String?> openNewCategorySheet(BuildContext context) {
  return showAppSheet<String>(context, const _NewCategoryForm());
}

class _NewCategoryForm extends StatefulWidget {
  const _NewCategoryForm();

  @override
  State<_NewCategoryForm> createState() => _NewCategoryFormState();
}

class _NewCategoryFormState extends State<_NewCategoryForm> {
  final _name = TextEditingController();
  int _icon = 0;
  int _color = 0;
  bool _essential = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('اكتب اسم الفئة')));
      return;
    }
    final s = context.read<AppStore>();
    if (allCategories.any((c) => c.name == name)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('هذه الفئة موجودة')));
      return;
    }
    s.addCategory(name, _icon, _color, _essential);
    HapticFeedback.mediumImpact();
    Navigator.pop(context, customCategories.last.id);
  }

  @override
  Widget build(BuildContext context) {
    final color = kCategoryColors[_color];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(kCategoryIcons[_icon], color: color),
          ),
          const SizedBox(width: 12),
          const Text('فئة جديدة',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(
              labelText: 'اسم الفئة', hintText: 'مثال: بنزين', counterText: ''),
        ),
        const SizedBox(height: 14),
        const Text('الأيقونة',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < kCategoryIcons.length; i++)
              GestureDetector(
                onTap: () => setState(() => _icon = i),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: i == _icon
                        ? color.withValues(alpha: 0.18)
                        : AppColors.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: i == _icon ? color : Colors.transparent),
                  ),
                  child: Icon(kCategoryIcons[i],
                      size: 20, color: i == _icon ? color : AppColors.muted),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        const Text('اللون',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < kCategoryColors.length; i++)
              GestureDetector(
                onTap: () => setState(() => _color = i),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: kCategoryColors[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: i == _color ? Colors.white : Colors.transparent,
                        width: 2.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _essential,
          onChanged: (v) => setState(() => _essential = v),
          title: const Text('مصروف ضروري افتراضياً'),
          subtitle: Text(
              _essential
                  ? 'سيُعلَّم كضروري عند الإضافة'
                  : 'سيُحسب ضمن الهدر عند الإضافة',
              style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('إضافة الفئة')),
      ],
    );
  }
}
