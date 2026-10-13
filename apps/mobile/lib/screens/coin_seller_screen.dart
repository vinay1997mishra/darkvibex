import 'package:flutter/material.dart';

import '../app/app_state.dart';
import 'wallet_detail_screens.dart';

class CoinSellerScreen extends StatelessWidget {
  const CoinSellerScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return RoleWalletDetailScreen(
      state: state,
      walletType: 'coin_seller',
    );
  }
}
