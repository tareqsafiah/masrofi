import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// إعدادات قاعدة البيانات السحابية (ملف مشفّر داخل مستودع GitHub)
class CloudConfig {
  final String owner;
  final String repo;
  final String token;
  final String password;

  const CloudConfig({
    required this.owner,
    required this.repo,
    required this.token,
    required this.password,
  });

  Map<String, dynamic> toJson() =>
      {'owner': owner, 'repo': repo, 'token': token, 'password': password};

  factory CloudConfig.fromJson(Map<String, dynamic> j) => CloudConfig(
        owner: j['owner'] as String,
        repo: j['repo'] as String,
        token: (j['token'] ?? '') as String,
        password: j['password'] as String,
      );
}

class CloudException implements Exception {
  final String message;
  CloudException(this.message);
  @override
  String toString() => message;
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
  static const _iterations = 150000;

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
  static final _aes = AesGcm.with256bits();

  Future<SecretKey> _key(List<int> salt) => Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: _iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: cfg.password, nonce: salt);

  Future<Map<String, dynamic>> _encrypt(Map<String, dynamic> data) async {
    final salt = _randomBytes(16);
    final key = await _key(salt);
    final box = await _aes.encrypt(
      utf8.encode(jsonEncode(data)),
      secretKey: key,
      nonce: _aes.newNonce(),
    );
    return {
      'v': 1,
      'alg': 'AES-256-GCM/PBKDF2-SHA256',
      'iter': _iterations,
      'updatedAt': data['updatedAt'],
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
      'data': base64Encode(box.cipherText),
    };
  }

  Future<Map<String, dynamic>> _decrypt(Map<String, dynamic> enc) async {
    final key = await _key(base64Decode(enc['salt'] as String));
    try {
      final clear = await _aes.decrypt(
        SecretBox(
          base64Decode(enc['data'] as String),
          nonce: base64Decode(enc['nonce'] as String),
          mac: Mac(base64Decode(enc['mac'] as String)),
        ),
        secretKey: key,
      );
      return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    } on SecretBoxAuthenticationError {
      throw CloudException('كلمة سر التشفير غير صحيحة');
    }
  }

  static Uint8List _randomBytes(int n) {
    final r = SecretKeyData.random(length: n);
    return Uint8List.fromList(r.bytes);
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
