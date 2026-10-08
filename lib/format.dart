import 'package:intl/intl.dart';

final _num = NumberFormat('#,##0.##', 'en');
final _num0 = NumberFormat('#,##0', 'en');

String money(double v, String symbol, {bool decimals = true}) {
  final s = (decimals ? _num : _num0).format(v.abs());
  final sign = v < 0 ? '-' : '';
  return symbol == '\$' ? '$sign\$$s' : '$sign$s $symbol';
}

String usd(double v) => money(v, '\$');

String pct(double v) => '${(v * 100).round()}%';

const _months = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

const _monthsShort = [
  'ك٢', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران', //
  'تموز', 'آب', 'أيلول', 'ت١', 'ت٢', 'ك١',
];

String monthName(DateTime d) => '${_months[d.month - 1]} ${d.year}';
String monthShort(DateTime d) => _monthsShort[d.month - 1];

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'اليوم';
  if (diff == 1) return 'أمس';
  return '${d.day} ${_months[d.month - 1]}';
}

String monthKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}';

int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;
