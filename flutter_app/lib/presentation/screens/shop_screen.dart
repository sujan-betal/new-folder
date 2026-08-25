import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../injection_container.dart' as di;
import '../../logic/providers/auth_provider.dart';
import '../../logic/providers/shop_provider.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => di.sl<ShopProvider>()..load(),
      child: const _ShopBody(),
    );
  }
}

class _ShopBody extends StatelessWidget {
  const _ShopBody();

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    const Text('Shop',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    if (user != null) ...[
                      _BalanceChip(
                          icon: Icons.monetization_on,
                          value: '${user.coins}'),
                      const SizedBox(width: 6),
                      _BalanceChip(
                          icon: Icons.diamond_outlined,
                          value: '${user.gems}'),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Avatars are usable in every game mode once owned.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: shop.loading && shop.items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold))
                    : GridView.builder(
                        padding: const EdgeInsets.all(18),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: shop.items.length,
                        itemBuilder: (context, index) {
                          final item = shop.items[index];
                          final canAfford = user != null &&
                              user.coins >= item.priceCoins &&
                              user.gems >= item.priceGems;
                          return _ItemCard(
                            emoji: item.emoji,
                            label: item.label,
                            priceLine: item.isFree
                                ? 'FREE'
                                : [
                                    if (item.priceCoins > 0)
                                      '${item.priceCoins} coins',
                                    if (item.priceGems > 0)
                                      '${item.priceGems} gems',
                                  ].join(' + '),
                            owned: item.owned || item.isFree,
                            equipped: item.equipped,
                            canAfford: canAfford,
                            busy: shop.purchasing,
                            onBuy: () async {
                              final ok = await shop.buy(item);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? '${item.label} unlocked!'
                                      : (shop.error ?? 'Purchase failed')),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PriceInfo {
  const PriceInfo(this.coins, this.gems);

  final int coins;
  final int gems;
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.emoji,
    required this.label,
    required this.priceLine,
    required this.owned,
    required this.equipped,
    required this.canAfford,
    required this.busy,
    this.onBuy,
  });

  final String emoji;
  final String label;
  final String priceLine;
  final bool owned;
  final bool equipped;
  final bool canAfford;
  final bool busy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: equipped ? AppColors.gold : Colors.white24,
          width: equipped ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 4),
          Text(label,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(priceLine,
              style: TextStyle(
                  fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
          const SizedBox(height: 8),
          if (equipped)
            const Text('EQUIPPED',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.gold))
          else if (owned)
            const Text('OWNED',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white60))
          else
            GestureDetector(
              onTap: canAfford && !busy ? onBuy : null,
              child: Opacity(
                opacity: canAfford && !busy ? 1 : 0.45,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(busy ? '...' : 'BUY',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF4A2C00))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
