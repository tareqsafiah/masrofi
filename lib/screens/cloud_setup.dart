import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../cloud.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

enum AuthMode { login, create }

/// نافذة الحساب: تسجيل الدخول أو إنشاء حساب
Future<void> openAuth(BuildContext context,
    {AuthMode mode = AuthMode.login}) {
  return showAppSheet(context, AuthForm(initial: mode));
}

/// للتوافق مع الأزرار القديمة
Future<void> openCloudSetup(BuildContext context, {bool restore = false}) {
  final s = context.read<AppStore>();
  return openAuth(context,
      mode: restore || s.cloud == null ? AuthMode.login : AuthMode.create);
}

class AuthForm extends StatefulWidget {
  final AuthMode initial;
  const AuthForm({super.key, this.initial = AuthMode.login});

  @override
  State<AuthForm> createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  late AuthMode _mode = widget.initial;
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final _token = TextEditingController();
  final _oldPass = TextEditingController();
  bool _busy = false;
  bool _showPass = false;
  bool _changeToken = false;
  bool _needOldPass = false;
  String? _error;
  String _stage = '';

  bool get _create => _mode == AuthMode.create;

  @override
  void initState() {
    super.initState();
    final c = context.read<AppStore>().cloud;
    if (c != null && c.username.isNotEmpty) _user.text = c.username;
  }

  @override
  void dispose() {
    for (final c in [_user, _pass, _pass2, _token, _oldPass]) {
      c.dispose();
    }
    super.dispose();
  }

  void _switch(AuthMode m) => setState(() {
        _mode = m;
        _error = null;
        _needOldPass = false;
      });

  Future<void> _submit() async {
    final store = context.read<AppStore>();
    final hasSavedToken = (store.cloud?.token ?? '').isNotEmpty;
    final user = _user.text.trim();
    final pass = _pass.text;
    String? err;
    if (user.length < 3) {
      err = 'اسم المستخدم 3 أحرف على الأقل';
    } else if (pass.length < 8) {
      err = 'كلمة المرور 8 أحرف على الأقل';
    } else if (_create && pass != _pass2.text) {
      err = 'كلمتا المرور غير متطابقتين';
    } else if (_create &&
        (!hasSavedToken || _changeToken) &&
        _token.text.trim().isEmpty) {
      err = 'أدخل رمز الوصول (Token) — مرة واحدة فقط';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _stage = _create ? 'جارٍ إنشاء الحساب...' : 'جارٍ التحقق...';
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final bool restored;
      if (_create) {
        restored = await store.createAccount(
          username: user,
          password: pass,
          token: _changeToken || !hasSavedToken ? _token.text : '',
          oldDataPassword: _needOldPass ? _oldPass.text : null,
        );
      } else {
        if (mounted) setState(() => _stage = 'جارٍ تحميل بياناتك...');
        restored = await store.login(user, pass);
      }
      if (restored && !store.onboarded) {
        store.updateSettings(onboarded: true);
      }
      HapticFeedback.mediumImpact();
      nav.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(_create
              ? 'تم إنشاء الحساب ✓ من الآن يكفي اسم المستخدم وكلمة المرور'
              : restored
                  ? 'أهلاً $user، تم تحميل بياناتك ✓'
                  : 'تم تسجيل الدخول ✓')));
    } on WrongDataPassword {
      setState(() {
        _needOldPass = true;
        _error = _oldPass.text.isEmpty
            ? 'توجد بيانات سابقة مشفّرة بكلمة سر أخرى. أدخل كلمة سر التشفير القديمة لربطها بحسابك.'
            : 'كلمة سر التشفير القديمة غير صحيحة';
      });
    } on CloudException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر الاتصال. تأكد من الإنترنت وحاول مجدداً');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _modeSwitch() => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          for (final (m, label) in [
            (AuthMode.login, 'تسجيل الدخول'),
            (AuthMode.create, 'إنشاء حساب'),
          ])
            Expanded(
              child: GestureDetector(
                onTap: _busy ? null : () => _switch(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _mode == m ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _mode == m
                              ? const Color(0xFF04140E)
                              : AppColors.muted)),
                ),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final hasSavedToken = (store.cloud?.token ?? '').isNotEmpty;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_create ? 'إنشاء حساب' : 'تسجيل الدخول',
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
              _create
                  ? 'تُدخل رمز الوصول مرة واحدة فقط هنا، ويُحفظ مشفّراً بكلمة مرورك. بعدها تسجّل الدخول من أي جهاز باسم المستخدم وكلمة المرور.'
                  : 'أدخل اسم المستخدم وكلمة المرور لتحميل بياناتك المحفوظة.',
              style: const TextStyle(color: AppColors.muted, height: 1.6)),
          const SizedBox(height: 16),
          _modeSwitch(),
          const SizedBox(height: 16),
          TextField(
            controller: _user,
            enabled: !_busy,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
                labelText: 'اسم المستخدم',
                prefixIcon: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pass,
            enabled: !_busy,
            obscureText: !_showPass,
            autocorrect: false,
            autofillHints: [
              _create ? AutofillHints.newPassword : AutofillHints.password
            ],
            textInputAction:
                _create ? TextInputAction.next : TextInputAction.done,
            onSubmitted: _create ? null : (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'كلمة المرور',
              prefixIcon: const Icon(Icons.lock_rounded),
              helperText: _create
                  ? 'احفظها جيداً: لا يمكن استرجاعها، وبها تُفك بياناتك'
                  : null,
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(_showPass
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          if (_create) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _pass2,
              enabled: !_busy,
              obscureText: !_showPass,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: Icon(Icons.lock_outline_rounded)),
            ),
            const SizedBox(height: 12),
            if (hasSavedToken && !_changeToken)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Icon(Icons.key_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                        'سيُستخدم رمز الوصول المحفوظ على هذا الجهاز، فلا حاجة لإدخاله.',
                        style: TextStyle(fontSize: 13, height: 1.5)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _changeToken = true),
                    child: const Text('تغيير'),
                  ),
                ]),
              )
            else
              TextField(
                controller: _token,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: 'رمز الوصول (Token)',
                  hintText: 'github_pat_...',
                  prefixIcon: Icon(Icons.key_rounded),
                  helperText: 'مرة واحدة فقط عند إنشاء الحساب',
                ),
              ),
            if (_needOldPass) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _oldPass,
                enabled: !_busy,
                obscureText: true,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'كلمة سر التشفير القديمة',
                  prefixIcon: Icon(Icons.history_rounded),
                ),
              ),
            ],
          ],
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
            onPressed: _busy ? null : _submit,
            child: _busy
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 12),
                    Text(_stage),
                  ])
                : Text(_create ? 'إنشاء الحساب' : 'دخول'),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _busy
                ? null
                : () => _switch(_create ? AuthMode.login : AuthMode.create),
            child: Text(_create
                ? 'لديك حساب؟ تسجيل الدخول'
                : 'ليس لديك حساب؟ إنشاء حساب'),
          ),
        ],
      ),
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
