class DiamondExchange {
  static const int diamondsPerExactStep = 5;
  static const int coinsPerExactStep = 3;

  static int coinsForDiamonds(int diamonds) {
    if (diamonds <= 0) return 0;
    return (diamonds * coinsPerExactStep) ~/ diamondsPerExactStep;
  }

  static bool isExactAmount(int diamonds) =>
      diamonds > 0 && diamonds % diamondsPerExactStep == 0;
}
