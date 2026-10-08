import 'dart:convert';

import 'package:http/http.dart' as http;

/// أسعار السوق كما تأتي من sp-today.com (بالليرة السورية القديمة)
///
/// ملاحظة: "buy" = السعر الذي يشتري به الصرّاف منك (تستخدمه عند البيع)
///         "sell" = السعر الذي يبيعك به الصرّاف (تستخدمه عند الشراء)
class Rates {
  final double usdBuy;
  final double usdSell;
  final double g21Buy;
  final double g21Sell;
  final double g18Buy;
  final double g18Sell;
  final DateTime fetchedAt;

  const Rates({
    required this.usdBuy,
    required this.usdSell,
    required this.g21Buy,
    required this.g21Sell,
    required this.g18Buy,
    required this.g18Sell,
    required this.fetchedAt,
  });

  Map<String, dynamic> toJson() => {
        'usd': {'buy': usdBuy, 'sell': usdSell},
        'gold': {
          '21K': {'buy': g21Buy, 'sell': g21Sell},
          '18K': {'buy': g18Buy, 'sell': g18Sell},
        },
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  factory Rates.fromJson(Map<String, dynamic> j) {
    double n(dynamic v) => (v as num).toDouble();
    final usd = j['usd'] as Map<String, dynamic>;
    final gold = j['gold'] as Map<String, dynamic>;
    final g21 = gold['21K'] as Map<String, dynamic>;
    final g18 = gold['18K'] as Map<String, dynamic>;
    return Rates(
      usdBuy: n(usd['buy']),
      usdSell: n(usd['sell']),
      g21Buy: n(g21['buy']),
      g21Sell: n(g21['sell']),
      g18Buy: n(g18['buy']),
      g18Sell: n(g18['sell']),
      fetchedAt: DateTime.tryParse(
              (j['sourceUpdatedAt'] ?? j['fetchedAt'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  /// يستخرج الأسعار من صفحة الموقع مباشرة (مسار احتياطي)
  static Rates? parseHtml(String html) {
    final u = html.replaceAll(r'\"', '"');
    final usd = RegExp(
            r'"code":"USD".*?"damascus":\{"buy":([\d.]+),"sell":([\d.]+)',
            dotAll: true)
        .firstMatch(u);
    if (usd == null) return null;
    final gi = u.indexOf('"gold":{"karats"');
    final gold = <String, List<double>>{};
    for (final m in RegExp(
            r'"karat":"(\d+K)","cities":\{"damascus":\{"buy":([\d.]+),"sell":([\d.]+)')
        .allMatches(gi >= 0 ? u.substring(gi) : u)) {
      gold[m.group(1)!] = [double.parse(m.group(2)!), double.parse(m.group(3)!)];
    }
    if (gold['21K'] == null || gold['18K'] == null) return null;
    return Rates(
      usdBuy: double.parse(usd.group(1)!),
      usdSell: double.parse(usd.group(2)!),
      g21Buy: gold['21K']![0],
      g21Sell: gold['21K']![1],
      g18Buy: gold['18K']![0],
      g18Sell: gold['18K']![1],
      fetchedAt: DateTime.now(),
    );
  }
}

class RatesService {
  static const _primary =
      'https://raw.githubusercontent.com/tareqsafiah/masrofi/rates/rates.json';
  static const _fallback =
      'https://api.allorigins.win/raw?url=https%3A%2F%2Fsp-today.com%2F';

  /// يجلب أحدث الأسعار: أولاً من المستودع (يُحدَّث كل 30 دقيقة)، ثم من الموقع مباشرة
  static Future<Rates?> fetch() async {
    try {
      final r = await http
          .get(Uri.parse('$_primary?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        return Rates.fromJson(
            jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
      }
    } catch (e) {
      // ignore: avoid_print
      print('rates primary failed: $e');
    }
    try {
      final r = await http
          .get(Uri.parse(_fallback))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode == 200) return Rates.parseHtml(utf8.decode(r.bodyBytes));
    } catch (_) {}
    return null;
  }
}

/// أنواع الأصول في المدخرات
enum Asset { usd, gold21, gold18 }

extension AssetX on Asset {
  String get label => switch (this) {
        Asset.usd => 'دولار',
        Asset.gold21 => 'ذهب عيار 21',
        Asset.gold18 => 'ذهب عيار 18',
      };
  String get unit => this == Asset.usd ? 'USD' : 'غرام';
  String get key => switch (this) {
        Asset.usd => 'usd',
        Asset.gold21 => 'g21',
        Asset.gold18 => 'g18',
      };
  static Asset fromKey(String k) =>
      Asset.values.firstWhere((a) => a.key == k, orElse: () => Asset.usd);
}
