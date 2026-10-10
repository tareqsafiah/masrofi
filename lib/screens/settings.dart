import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../format.dart';
import '../models.dart';
import '../rates.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'categories.dart';
import 'cloud_setup.dart';

const kCurrencies = ['\$', 'ل.س', 'ل.س ق', '€', '£', 'ر.س', 'د.إ', 'TL'];

String currencyLabel(String c) => switch (c) {
      'ل.س' => 'ليرة سورية جديدة',
      'ل.س ق' => 'ليرة سورية قديمة',
      _ => c,
    };

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final cur = s.currency;
    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const SectionTitle('الدخل والميزانية'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _row(
                context,
                icon: Icons.payments_rounded,
                title: 'الدخل الشهري الافتراضي',
                value: s.defaultIncome > 0
                    ? money(s.defaultIncome, cur, decimals: false)
                    : 'غير محدد',
                onTap: () => _editNumber(context, 'الدخل الشهري الافتراضي',
                    s.defaultIncome, cur, (v) => s.updateSettings(defaultIncome: v)),
              ),
              const Divider(indent: 56),
              _row(
                context,
                icon: Icons.edit_calendar_rounded,
                title: 'دخل ${monthName(s.selectedMonth)}',
                value: money(s.incomeFor(s.selectedMonth), cur, decimals: false) +
                    (s.hasCustomIncome(s.selectedMonth) ? '' : ' (افتراضي)'),
                onTap: () => _editNumber(
                  context,
                  'دخل ${monthName(s.selectedMonth)}',
                  s.incomeFor(s.selectedMonth),
                  cur,
                  (v) => s.setIncomeFor(s.selectedMonth, v),
                  hint: 'إذا اختلف دخل هذا الشهر (مكافأة، عمل إضافي...)',
                  onReset: s.hasCustomIncome(s.selectedMonth)
                      ? () => s.clearIncomeFor(s.selectedMonth)
                      : null,
                ),
              ),
              const Divider(indent: 56),
              _row(
                context,
                icon: Icons.speed_rounded,
                title: 'حد الصرف الشهري',
                value: s.monthlyBudget > 0
                    ? money(s.monthlyBudget, cur, decimals: false)
                    : 'بدون حد',
                onTap: () => _editNumber(context, 'حد الصرف الشهري',
                    s.monthlyBudget, cur, (v) => s.updateSettings(monthlyBudget: v),
                    hint: 'أقصى مبلغ تريد صرفه شهرياً. ضع 0 لإلغائه'),
              ),
            ]),
          ),
          const SectionTitle('عملة المصاريف والدخل'),
          AppCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in kCurrencies)
                  ChoiceChip(
                    label: Text(currencyLabel(c)),
                    selected: c == cur,
                    onSelected: (_) => s.updateSettings(currency: c),
                    selectedColor: AppColors.primary.withValues(alpha: 0.2),
                    backgroundColor: AppColors.surface2,
                    side: BorderSide(
                        color: c == cur ? AppColors.primary : Colors.transparent),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Text('محفظة الادخار تبقى دائماً بالدولار.',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ),
          const SectionTitle('المصاريف'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _row(
              context,
              icon: Icons.category_rounded,
              title: 'فئات المصاريف',
              value: '${customCategories.length} مضافة',
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CategoriesScreen())),
            ),
          ),
          const SectionTitle('قاعدة البيانات'),
          _CloudCard(store: s),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              _row(
                context,
                icon: Icons.copy_all_rounded,
                iconColor: AppColors.info,
                title: 'نسخ نسخة احتياطية',
                value: '',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: s.exportBackup()));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'تم نسخ بياناتك. الصقها في الملاحظات لحفظها')));
                },
              ),
              const Divider(indent: 56),
              _row(
                context,
                icon: Icons.content_paste_go_rounded,
                iconColor: AppColors.info,
                title: 'استيراد من نسخة احتياطية',
                value: '',
                onTap: () => _importBackup(context, s),
              ),
            ]),
          ),
          const SectionTitle('البيانات'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _row(
              context,
              icon: Icons.delete_forever_rounded,
              iconColor: AppColors.danger,
              title: 'حذف جميع البيانات',
              value: '',
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: AppColors.surface,
                    title: const Text('حذف كل البيانات؟'),
                    content: const Text(
                        'سيتم حذف جميع المصاريف والمحفظة والإعدادات نهائياً.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('إلغاء')),
                      TextButton(
                          onPressed: () => Navigator.pop(c, true),
                          child: const Text('حذف',
                              style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (ok == true) {
                  await s.resetAll();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('مصروفي · نسخة شخصية 1.1\nبياناتك مشفّرة ولا يمكن لأحد غيرك قراءتها',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.6)),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context,
      {required IconData icon,
      required String title,
      required String value,
      required VoidCallback onTap,
      Color iconColor = AppColors.primary}) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: iconColor),
      title: Text(title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: const TextStyle(color: AppColors.muted)),
        const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
      ]),
    );
  }
}

class _CloudCard extends StatelessWidget {
  final AppStore store;
  const _CloudCard({required this.store});

  Widget _prompt(BuildContext context,
      {required IconData icon,
      required Color color,
      required String title,
      required String body,
      required AuthMode mode}) {
    return AppCard(
      onTap: () => openAuth(context, mode: mode),
      child: Row(children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        const Icon(Icons.chevron_left_rounded, color: AppColors.muted),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = store;
    if (!s.cloudEnabled) {
      return Column(children: [
        _prompt(context,
            icon: Icons.login_rounded,
            color: AppColors.primary,
            title: 'تسجيل الدخول',
            body: 'لديك حساب؟ ادخل باسم المستخدم وكلمة المرور لتحميل بياناتك.',
            mode: AuthMode.login),
        const SizedBox(height: 10),
        _prompt(context,
            icon: Icons.person_add_alt_1_rounded,
            color: AppColors.warning,
            title: 'إنشاء حساب',
            body:
                'بياناتك الآن في المتصفح فقط. أنشئ حساباً لحفظها مشفّرة حتى لا تضيع.',
            mode: AuthMode.create),
      ]);
    }
    final (label, color) = switch (s.syncState) {
      SyncState.ok => ('محفوظ ومتزامن', AppColors.primary),
      SyncState.syncing => ('جارٍ الحفظ...', AppColors.info),
      SyncState.error => (s.syncError ?? 'خطأ', AppColors.danger),
      SyncState.off => ('غير مربوط', AppColors.muted),
    };
    final t = s.lastSync;
    final hasAccount = s.username.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                  hasAccount ? s.username.characters.first.toUpperCase() : '؟',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hasAccount ? s.username : 'بدون حساب',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5)),
                ],
              ),
            ),
            Icon(Icons.cloud_done_rounded, color: color),
          ]),
          const SizedBox(height: 8),
          Text(
              'مشفّرة AES-256'
              '${t == null ? '' : ' · آخر مزامنة ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'}',
              style: const TextStyle(
                  color: AppColors.muted, fontSize: 12.5, height: 1.6)),
          if (!hasAccount) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => openAuth(context, mode: AuthMode.create),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('أنشئ اسم مستخدم وكلمة مرور'),
            ),
            const SizedBox(height: 4),
            const Text(
                'لتسجيل الدخول لاحقاً بدون رمز الوصول. سيُستخدم الرمز المحفوظ تلقائياً.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: s.syncState == SyncState.syncing ? null : s.syncNow,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: const Text('مزامنة الآن'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger),
                onPressed: () => s.disconnectCloud(),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(hasAccount ? 'تسجيل الخروج' : 'فصل'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

void _importBackup(BuildContext context, AppStore s) {
  final c = TextEditingController();
  showAppSheet(
    context,
    Builder(builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('استيراد نسخة احتياطية',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('الصق النص الذي نسخته سابقاً. سيستبدل البيانات الحالية.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextField(
            controller: c,
            maxLines: 5,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: '{"v":1, ...}'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(ctx);
              final nav = Navigator.of(ctx);
              try {
                await s.importBackup(c.text);
                nav.pop();
                messenger.showSnackBar(
                    const SnackBar(content: Text('تم استيراد البيانات ✓')));
              } catch (_) {
                messenger.showSnackBar(const SnackBar(
                    content: Text('النص غير صالح، تأكد أنك نسخته كاملاً')));
              }
            },
            child: const Text('استيراد'),
          ),
        ],
      );
    }),
  );
}

void _editNumber(BuildContext context, String title, double current,
    String currency, ValueChanged<double> onSave,
    {String? hint, VoidCallback? onReset}) {
  final c =
      TextEditingController(text: current > 0 ? current.toStringAsFixed(0) : '');
  showAppSheet(
    context,
    Builder(builder: (ctx) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint, style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 16),
          AmountField(
              controller: c, label: 'المبلغ', suffix: currency, autofocus: true),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              onSave(parseAmount(c.text) ?? 0);
              Navigator.pop(ctx);
            },
            child: const Text('حفظ'),
          ),
          if (onReset != null)
            TextButton(
              onPressed: () {
                onReset();
                Navigator.pop(ctx);
              },
              child: const Text('العودة للدخل الافتراضي'),
            ),
        ],
      );
    }),
  );
}

/// شاشة الترحيب عند أول تشغيل
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _income = TextEditingController();
  final _wallet = TextEditingController();
  final _syp = TextEditingController();
  final _rate = TextEditingController();
  bool _rateEdited = false;
  String _cur = '\$';

  bool get _isSyp => _cur == 'ل.س' || _cur == 'ل.س ق';

  /// سعر مبيع الدولار من الموقع بوحدة الليرة المختارة
  double? _siteRate(AppStore s) {
    final r = s.rates;
    if (r == null || !_isSyp) return null;
    return _cur == 'ل.س' ? r.usdSell / 100 : r.usdSell;
  }

  String _fmtRate(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void dispose() {
    _income.dispose();
    _wallet.dispose();
    _syp.dispose();
    _rate.dispose();
    super.dispose();
  }

  Widget _buyUsdCard(AppStore s) {
    final site = _siteRate(s);
    if (!_rateEdited && site != null) {
      final txt = _fmtRate(site);
      if (_rate.text != txt) _rate.text = txt;
    }
    final syp = parseAmount(_syp.text) ?? 0;
    final rate = parseAmount(_rate.text) ?? 0;
    final usdOut = rate > 0 ? syp / rate : 0.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.currency_exchange_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Expanded(
              child: Text('شراء مدخرات بالدولار (اختياري)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('أدخل المبلغ بالليرة الذي تريد تحويله إلى دولار.',
              style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 14),
          TextField(
            controller: _syp,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration:
                InputDecoration(labelText: 'المبلغ بالليرة', suffixText: _cur),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rate,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _rateEdited = true),
            decoration: InputDecoration(
              labelText: 'سعر شراء الدولار',
              suffixText: '$_cur / \$',
              helperText: site == null
                  ? (s.ratesLoading
                      ? 'جارٍ جلب السعر من الليرة اليوم...'
                      : 'تعذّر جلب السعر، أدخله يدوياً')
                  : _rateEdited
                      ? 'سعر معدّل يدوياً'
                      : 'سعر المبيع في دمشق من موقع الليرة اليوم',
            ),
          ),
          if (_rateEdited && site != null)
            TextButton.icon(
              onPressed: () => setState(() => _rateEdited = false),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('استخدام سعر الموقع (${_fmtRate(site)})'),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              const Text('ستحصل على',
                  style: TextStyle(color: AppColors.muted)),
              const Spacer(),
              Text(usd(usdOut),
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
            ]),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 30),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark]),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.savings_rounded,
                  size: 38, color: Color(0xFF04140E)),
            ),
            ),
            const SizedBox(height: 24),
            const Text('أهلاً بك في مصروفي',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
                'تابع مصاريفك، اكتشف الهدر، وابنِ مدّخراتك بالدولار. لنبدأ بخطوتين سريعتين.',
                style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.6)),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => openAuth(context, mode: AuthMode.login),
              icon: const Icon(Icons.login_rounded),
              label: const Text('لدي حساب: تسجيل الدخول'),
            ),
            const SizedBox(height: 30),
            const Text('عملة مصاريفك ودخلك',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in kCurrencies)
                ChoiceChip(
                  label: Text(currencyLabel(c)),
                  selected: c == _cur,
                  onSelected: (_) => setState(() => _cur = c),
                  selectedColor: AppColors.primary.withValues(alpha: 0.2),
                  backgroundColor: AppColors.surface2,
                  side: BorderSide(
                      color: c == _cur ? AppColors.primary : Colors.transparent),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
            ]),
            if (_cur == 'ل.س' || _cur == 'ل.س ق') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(children: [
                  Icon(Icons.currency_exchange_rounded,
                      color: AppColors.info, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'ستتمكن من شراء الدولار والذهب بأسعار موقع "الليرة اليوم" مباشرة، مع إمكانية تعديل السعر.',
                        style: TextStyle(fontSize: 13, height: 1.5)),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            AmountField(
                controller: _income, label: 'دخلك الشهري', suffix: _cur),
            const SizedBox(height: 14),
            AmountField(
                controller: _wallet,
                label: 'دولارات تملكها حالياً (اختياري)',
                suffix: 'USD'),
            if (_isSyp) ...[
              const SizedBox(height: 16),
              _buyUsdCard(store),
            ],
            const SizedBox(height: 30),
            FilledButton(
              onPressed: () {
                final s = context.read<AppStore>();
                final w = parseAmount(_wallet.text) ?? 0;
                if (w > 0) {
                  s.addWalletTx(WalletTx(
                      id: s.newId(),
                      amount: w,
                      date: DateTime.now(),
                      note: 'الرصيد الافتتاحي'));
                }
                s.updateSettings(
                  currency: _cur,
                  defaultIncome: parseAmount(_income.text) ?? 0,
                );
                final syp = parseAmount(_syp.text) ?? 0;
                final rate = parseAmount(_rate.text) ?? 0;
                if (_isSyp && syp > 0 && rate > 0) {
                  s.trade(Asset.usd,
                      buy: true,
                      qty: syp / rate,
                      price: rate,
                      note: 'شراء مدخرات عند البدء');
                }
                s.updateSettings(onboarded: true);
              },
              child: const Text('ابدأ'),
            ),
          ],
        ),
      ),
    );
  }
}
