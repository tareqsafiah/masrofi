import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// إعدادات قاعدة البيانات السحابية (ملف مشفّر داخل مستودع GitHub)
class CloudConfig {
  final String owner;
  final String repo;
  final String token;
  final String password; // كلمة سر تشفير البيانات
  final String username; // اسم المستخدم (فارغ للربط القديم بدون حساب)

  const CloudConfig({
    required this.owner,
    required this.repo,
    required this.token,
    required this.password,
    this.username = '',
  });

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'repo': repo,
        'token': token,
        'password': password,
        'username': username,
      };

  factory CloudConfig.fromJson(Map<String, dynamic> j) => CloudConfig(
        owner: j['owner'] as String,
        repo: j['repo'] as String,
        token: (j['token'] ?? '') as String,
        password: j['password'] as String,
        username: (j['username'] ?? '') as String,
      );

  CloudConfig copyWith({String? username}) => CloudConfig(
        owner: owner,
        repo: repo,
        token: token,
        password: password,
        username: username ?? this.username,
      );
}

/// المستودع الافتراضي لقاعدة البيانات
const kDefaultOwner = 'tareqsafiah';
const kDefaultRepo = 'masrofi';

class CloudException implements Exception {
  final String message;
  CloudException(this.message);
  @override
  String toString() => message;
}

/// البيانات السحابية مشفّرة بكلمة سر مختلفة
class WrongDataPassword extends CloudException {
  WrongDataPassword() : super('كلمة سر التشفير غير صحيحة');
}

/// نتيجة القراءة من السحابة
class RemoteSnapshot {
  final Map<String, dynamic> data;
  final DateTime updatedAt;
  RemoteSnapshot(this.data, this.updatedAt);
}

/// قاعدة بيانات خفيفة: ملف JSON مشفّر (AES-256-GCM) في فرع "data" بالمستودع.
/// التشفير يتم على الهاتف قبل الرفع، فلا يمكن لأحد قراءة البيانات بدون كلمة السر.
class CloudDb {
  static const _path = 'masrofi.enc.json';
  static const _branch = 'data';
  final CloudConfig cfg;
  String? _sha;

  CloudDb(this.cfg);

  Map<String, String> get _headers => {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        if (cfg.token.isNotEmpty) 'Authorization': 'Bearer ${cfg.token}',
      };

  String get _base => 'https://api.github.com/repos/${cfg.owner}/${cfg.repo}';

  // ---------------- التشفير ----------------
  Future<Map<String, dynamic>> _encrypt(Map<String, dynamic> data) async {
    final enc = await Vault.seal(cfg.password, data);
    enc['updatedAt'] = data['updatedAt'];
    return enc;
  }

  Future<Map<String, dynamic>> _decrypt(Map<String, dynamic> enc) async {
    final d = await Vault.open(cfg.password, enc);
    if (d == null) throw WrongDataPassword();
    return d;
  }

  // ---------------- GitHub ----------------
  void _check(http.Response r, String action) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    switch (r.statusCode) {
      case 401:
        throw CloudException('رمز الوصول (Token) غير صالح أو منتهي');
      case 403:
        throw CloudException(
            'الرمز لا يملك صلاحية الكتابة على المستودع (Contents: Read and write)');
      case 404:
        throw CloudException('المستودع غير موجود أو الرمز لا يملك صلاحية عليه');
      default:
        throw CloudException('فشل $action (${r.statusCode})');
    }
  }

  /// يقرأ النسخة السحابية. يعيد null إن لم توجد بعد.
  Future<RemoteSnapshot?> pull() async {
    final r = await http.get(
      Uri.parse('$_base/contents/$_path?ref=$_branch'),
      headers: _headers,
    );
    if (r.statusCode == 404) {
      _sha = null;
      return null;
    }
    _check(r, 'القراءة');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    _sha = body['sha'] as String?;
    final raw = utf8.decode(
        base64Decode((body['content'] as String).replaceAll('\n', '')));
    final enc = jsonDecode(raw) as Map<String, dynamic>;
    final data = await _decrypt(enc);
    final updated =
        DateTime.tryParse((data['updatedAt'] ?? '') as String) ?? DateTime(2000);
    return RemoteSnapshot(data, updated);
  }

  Future<void> _ensureBranch() async {
    final r = await http.get(Uri.parse('$_base/git/ref/heads/$_branch'),
        headers: _headers);
    if (r.statusCode == 200) return;
    final repo = await http.get(Uri.parse(_base), headers: _headers);
    _check(repo, 'قراءة المستودع');
    final def =
        (jsonDecode(repo.body) as Map<String, dynamic>)['default_branch'];
    final head = await http.get(Uri.parse('$_base/git/ref/heads/$def'),
        headers: _headers);
    _check(head, 'قراءة الفرع');
    final sha = ((jsonDecode(head.body) as Map)['object'] as Map)['sha'];
    final c = await http.post(
      Uri.parse('$_base/git/refs'),
      headers: _headers,
      body: jsonEncode({'ref': 'refs/heads/$_branch', 'sha': sha}),
    );
    if (c.statusCode != 422) _check(c, 'إنشاء فرع البيانات');
  }

  /// يرفع البيانات مشفّرة. يعيد المحاولة مرة عند تعارض النسخ.
  Future<void> push(Map<String, dynamic> data) async {
    if (cfg.token.isEmpty) {
      throw CloudException('أدخل رمز الوصول (Token) لتفعيل الحفظ السحابي');
    }
    final enc = await _encrypt(data);
    final content = base64Encode(
        utf8.encode(const JsonEncoder.withIndent(' ').convert(enc)));

    Future<http.Response> put() => http.put(
          Uri.parse('$_base/contents/$_path'),
          headers: _headers,
          body: jsonEncode({
            'message': 'sync ${data['updatedAt']}',
            'content': content,
            'branch': _branch,
            if (_sha != null) 'sha': _sha,
          }),
        );

    var r = await put();
    if (r.statusCode == 404 || (r.statusCode == 422 && _sha == null)) {
      await _ensureBranch();
      r = await put();
    }
    if (r.statusCode == 409 || r.statusCode == 422) {
      // النسخة تغيّرت: نحدّث المعرّف ونعيد المحاولة
      final g = await http.get(
          Uri.parse('$_base/contents/$_path?ref=$_branch'),
          headers: _headers);
      _sha = g.statusCode == 200
          ? (jsonDecode(g.body) as Map<String, dynamic>)['sha'] as String?
          : null;
      r = await put();
    }
    _check(r, 'الحفظ');
    _sha = ((jsonDecode(r.body) as Map)['content'] as Map)['sha'] as String?;
  }
}

/// تشفير AES-256-GCM بمفتاح مشتق من كلمة السر (PBKDF2-SHA256)
class Vault {
  static const iterations = 150000;
  static final _aes = AesGcm.with256bits();

  static Future<SecretKey> _key(String password, List<int> salt, int iter) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iter, bits: 256)
          .deriveKeyFromPassword(password: password, nonce: salt);

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList(SecretKeyData.random(length: n).bytes);

  static Future<Map<String, dynamic>> seal(
      String password, Map<String, dynamic> data) async {
    final salt = _randomBytes(16);
    final key = await _key(password, salt, iterations);
    final box = await _aes.encrypt(utf8.encode(jsonEncode(data)),
        secretKey: key, nonce: _aes.newNonce());
    return {
      'v': 1,
      'alg': 'AES-256-GCM/PBKDF2-SHA256',
      'iter': iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    };
  }

  /// يعيد null عند كلمة سر خاطئة
  static Future<Map<String, dynamic>?> open(
      String password, Map<String, dynamic> enc) async {
    final key = await _key(password, base64Decode(enc['salt'] as String),
        (enc['iter'] as num?)?.toInt() ?? iterations);
    try {
      final clear = await _aes.decrypt(
        SecretBox(base64Decode(enc['data'] as String),
            nonce: base64Decode(enc['nonce'] as String),
            mac: Mac(base64Decode(enc['mac'] as String))),
        secretKey: key,
      );
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      return null;
    }
  }
}

/// الحسابات: ملف مشفّر لكل مستخدم في فرع البيانات يحوي رمز الوصول.
/// يُدخل الرمز مرة واحدة عند إنشاء الحساب، وبعدها يكفي اسم المستخدم وكلمة المرور.
/// اسم الملف بصمة لاسم المستخدم فلا يظهر الاسم نفسه في المستودع.
class Accounts {
  static const _branch = 'data';

  static String normalize(String u) => u.trim().toLowerCase();

  static Future<String> path(String username) async {
    final h = await Sha256()
        .hash(utf8.encode('masrofi-account:${normalize(username)}'));
    final hex =
        h.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'accounts/${hex.substring(0, 40)}.json';
  }

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// يقرأ ملف الحساب (المستودع عام فلا حاجة لرمز). يعيد (المحتوى، sha) أو null.
  static Future<(Map<String, dynamic>, String?)?> fetch(
      String owner, String repo, String username,
      {String token = ''}) async {
    final p = await path(username);
    final r = await http.get(
      Uri.parse(
          'https://api.github.com/repos/$owner/$repo/contents/$p?ref=$_branch'),
      headers: _headers(token),
    );
    if (r.statusCode == 404) return null;
    if (r.statusCode == 200) {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final raw = utf8.decode(
          base64Decode((body['content'] as String).replaceAll('\n', '')));
      return (jsonDecode(raw) as Map<String, dynamic>, body['sha'] as String?);
    }
    // تجاوز حد الطلبات: نقرأ النسخة الخام
    final raw = await http.get(Uri.parse(
        'https://raw.githubusercontent.com/$owner/$repo/$_branch/$p'));
    if (raw.statusCode == 404) return null;
    if (raw.statusCode != 200) {
      throw CloudException('تعذّر الوصول إلى الحساب (${r.statusCode})');
    }
    return (jsonDecode(raw.body) as Map<String, dynamic>, null);
  }

  /// يفك ملف الحساب ويعيد إعدادات الاتصال، أو null عند كلمة مرور خاطئة
  static Future<CloudConfig?> unlock(
      Map<String, dynamic> enc, String username, String password) async {
    final d = await Vault.open(password, enc);
    if (d == null) return null;
    return CloudConfig(
      owner: d['owner'] as String,
      repo: d['repo'] as String,
      token: d['token'] as String,
      password: d['dataPass'] as String,
      username: (d['username'] ?? username.trim()) as String,
    );
  }

  /// ينشئ ملف الحساب أو يحدّثه (يتطلب رمزاً بصلاحية الكتابة)
  static Future<void> save(CloudConfig cfg, String password,
      {String? sha}) async {
    final enc = await Vault.seal(password, {
      'username': cfg.username,
      'owner': cfg.owner,
      'repo': cfg.repo,
      'token': cfg.token,
      'dataPass': cfg.password,
      'savedAt': DateTime.now().toIso8601String(),
    });
    final p = await path(cfg.username);
    final r = await http.put(
      Uri.parse(
          'https://api.github.com/repos/${cfg.owner}/${cfg.repo}/contents/$p'),
      headers: _headers(cfg.token),
      body: jsonEncode({
        'message': 'account',
        'content': base64Encode(
            utf8.encode(const JsonEncoder.withIndent(' ').convert(enc))),
        'branch': _branch,
        if (sha != null) 'sha': sha,
      }),
    );
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    throw CloudException(switch (r.statusCode) {
      401 => 'رمز الوصول (Token) غير صالح أو منتهي',
      403 => 'الرمز لا يملك صلاحية الكتابة على المستودع (Contents: Read and write)',
      404 => 'المستودع أو فرع البيانات غير موجود، أو الرمز لا يملك صلاحية عليه',
      _ => 'تعذّر حفظ الحساب (${r.statusCode})',
    });
  }
}
