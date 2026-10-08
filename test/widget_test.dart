import 'package:flutter_test/flutter_test.dart';
import 'package:masrofi/format.dart';
import 'package:masrofi/widgets.dart';

void main() {
  test('parseAmount يدعم الأرقام العربية والفواصل', () {
    expect(parseAmount('١٢٥'), 125);
    expect(parseAmount('1,250.5'), 1250.5);
    expect(parseAmount('abc'), isNull);
  });

  test('money يعرض الدولار بشكل صحيح', () {
    expect(money(1500, '\$', decimals: false), '\$1,500');
    expect(money(-20, '\$', decimals: false), '-\$20');
  });
}
