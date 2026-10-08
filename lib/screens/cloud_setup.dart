import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../cloud.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// نافذة ربط قاعدة البيانات السحابية (أو استعادة البيانات)
Future<void> openCloudSetup(BuildContext context, {bool restore = false}) {
  return showAppSheet(context, CloudSetupForm(restore: restore));
}

class CloudSetupForm extends StatefulWidget {
  final bool restore;
  const CloudSetupForm({super.key, this.restore = false});

  @override
  State<CloudSetupForm> createState() => _CloudSetupFormState();
}

class _CloudSetupFormState extends State<CloudSetupForm> {
  late final TextEditingController _owner;
  late final TextEditingController _repo;
  late final TextEditingController _token;
  late final TextEditingController _pass;
  bool _busy = false;
  bool _showPass = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppStore>().cloud;
    _owner = TextEditingController(text: c?.owner ?? 'tareqsafiah');
    _repo = TextEditingController(text: c?.repo ?? 'masrofi');
    _token = TextEditingController(text: c?.token ?? '');
    _pass = TextEditingController(text: c?.password ?? '');
  }

  @override
  void dispose() {
    _owner.dispose();
    _repo.dispose();
    _token.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final pass = _pass.text;
    if (pass.length < 8) {
      setState(() => _error = 'كلمة سر التشفير يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (_token.text.trim().isEmpty && !widget.restore) {
      setState(() => _error = 'أدخل رمز الوصول (Token)');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = context.read<AppStore>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final restored = await store.connectCloud(CloudConfig(
        owner: _owner.text.trim(),
        repo: _repo.text.trim(),
        token: _token.text.trim(),
        password: pass,
      ));
      if (restored && !store.onboarded) {
        store.updateSettings(onboarded: true);
      }
      HapticFeedback.mediumImpact();
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(restored
              ? 'تمت استعادة بياناتك من قاعدة البيانات ✓'
              : 'تم ربط قاعدة البيانات، وسيُحفظ كل تعديل تلقائياً ✓')));
    } on CloudException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال. تأكد من الإنترنت وحاول مجدداً');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.restore ? 'استعادة بياناتك' : 'قاعدة البيانات السحابية',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
            'تُحفظ بياناتك مشفّرة في مستودعك على GitHub، فلا تضيع إذا حُذفت بيانات المتصفح. التشفير يتم على هاتفك، ولا يمكن قراءتها بدون كلمة السر.',
            style: TextStyle(color: AppColors.muted, height: 1.6)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: TextField(
                controller: _owner,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'حساب GitHub')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
                controller: _repo,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'المستودع')),
          ),
        ]),
        const SizedBox(height: 12),
        TextField(
          controller: _token,
          obscureText: true,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'رمز الوصول (Token)',
            hintText: 'github_pat_...',
            helperText: widget.restore
                ? 'اختياري للاستعادة، ومطلوب لمتابعة الحفظ'
                : null,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pass,
          obscureText: !_showPass,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'كلمة سر التشفير',
            helperText: widget.restore
                ? 'نفس كلمة السر التي استخدمتها سابقاً'
                : 'احفظها جيداً: بدونها لا يمكن فك تشفير بياناتك',
            helperMaxLines: 2,
            suffixIcon: IconButton(
              icon: Icon(_showPass
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded),
              onPressed: () => setState(() => _showPass = !_showPass),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_error!,
                style: const TextStyle(color: AppColors.danger, height: 1.5)),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _connect,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : Text(widget.restore ? 'استعادة' : 'ربط وحفظ'),
        ),
      ],
    );
  }
}

/// أيقونة صغيرة تبيّن حالة المزامنة
class SyncBadge extends StatelessWidget {
  final VoidCallback? onTap;
  const SyncBadge({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final (icon, color) = switch (s.syncState) {
      SyncState.off => (Icons.cloud_off_rounded, AppColors.muted),
      SyncState.syncing => (Icons.cloud_sync_rounded, AppColors.info),
      SyncState.ok => (Icons.cloud_done_rounded, AppColors.primary),
      SyncState.error => (Icons.cloud_off_rounded, AppColors.danger),
    };
    return IconButton(
      tooltip: switch (s.syncState) {
        SyncState.off => 'قاعدة البيانات غير مربوطة',
        SyncState.syncing => 'جارٍ الحفظ...',
        SyncState.ok => 'محفوظ في قاعدة البيانات',
        SyncState.error => s.syncError ?? 'خطأ في المزامنة',
      },
      onPressed: onTap,
      icon: Icon(icon, color: color),
    );
  }
}
