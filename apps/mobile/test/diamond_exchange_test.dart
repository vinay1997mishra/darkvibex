import 'package:flutter_test/flutter_test.dart';
import 'package:darkvibex/utils/diamond_exchange.dart';

void main() {
  test('diamond exchange returns 60 percent as whole coins', () {
    expect(DiamondExchange.coinsForDiamonds(100), 60);
    expect(DiamondExchange.coinsForDiamonds(250), 150);
    expect(DiamondExchange.coinsForDiamonds(5), 3);
  });

  test('exact exchange accepts positive multiples of five only', () {
    expect(DiamondExchange.isExactAmount(100), isTrue);
    expect(DiamondExchange.isExactAmount(5), isTrue);
    expect(DiamondExchange.isExactAmount(101), isFalse);
    expect(DiamondExchange.isExactAmount(0), isFalse);
    expect(DiamondExchange.isExactAmount(-5), isFalse);
  });
}
