import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/shop_model.dart';
import '../../data/repositories/shop_repository.dart';
import '../../injection_container.dart' as di;
import '../../logic/providers/auth_provider.dart';
import '../../logic/providers/shop_provider.dart';
import '../widgets/primary_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => di.sl<ProfileProvider>()..loadHistory(),
      child: const _ProfileBody(),
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody();

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  List<ShopItemModel> _avatars = [];

  @override
  void initState() {
    super.initState();
    _loadAvatars();
  }

  Future<void> _loadAvatars() async {
    try {
      final items = await di.sl<ShopRepository>().items();
      if (!mounted) return;
      setState(() => _avatars = items);
    } catch (_) {}
  }

  Future<void> _equip(ShopItemModel item) async {
    final ok = await context.read<ProfileProvider>().equipAvatar(item.emoji);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Avatar updated!' : 'Could not equip avatar'),
      ),
    );
    if (ok) _loadAvatars();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final profile = context.watch<ProfileProvider>();

    final xpToNext = user == null ? 0 : user.level * 100;

    return Scaffold(
      body: Container(
        decoration:
            const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: user == null
              ? Center(
                  child: PrimaryButton(
                    label: 'Sign in',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 6),
                        const Text('My Profile',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor:
                                AppColors.royalBlue.withValues(alpha: 0.6),
                            child: Text(user.avatar,
                                style: const TextStyle(fontSize: 36)),
                          ),
                          const SizedBox(height: 10),
                          Text(user.username,
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w900)),
                          Text(user.email,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white.withValues(alpha: 0.55))),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceEvenly,
                            children: [
                              _Stat(icon: Icons.monetization_on,
                                  value: '${user.coins}', label: 'Coins'),
                              _Stat(icon: Icons.diamond_outlined,
                                  value: '${user.gems}', label: 'Gems'),
                              _Stat(icon: Icons.military_tech,
                                  value: 'Lvl ${user.level}',
                                  label: 'Level'),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: xpToNext == 0
                                        ? 0
                                        : (user.xp / xpToNext).clamp(0.0, 1.0),
                                    minHeight: 9,
                                    backgroundColor: Colors.white24,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            AppColors.gold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text('$xpToNext XP',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white
                                          .withValues(alpha: 0.6))),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('AVATARS',
                        style: TextStyle(
                            fontSize: 12,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 92,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _avatars.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final item = _avatars[index];
                          final equipped = item.emoji == user.avatar;
                          return GestureDetector(
                            onTap: item.owned || item.isFree
                                ? () => _equip(item)
                                : null,
                            child: Container(
                              width: 76,
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: equipped
                                      ? AppColors.gold
                                      : Colors.white24,
                                  width: equipped ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Text(item.emoji,
                                          style: const TextStyle(
                                              fontSize: 28)),
                                      if (!item.owned && !item.isFree)
                                        const Icon(Icons.lock,
                                            size: 13,
                                            color: Colors.white54),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    equipped ? 'ON' : '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.gold),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!auth.isAuthenticated)
                      const SizedBox.shrink()
                    else ...[
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Text('MATCH HISTORY',
                              style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.gold)),
                          const Spacer(),
                          if (profile.loadingHistory)
                            const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (profile.history.isEmpty &&
                          !profile.loadingHistory)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          child: Text(
                            profile.error ?? 'No matches played yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        )
                      else
                        for (final h in profile.history.take(15))
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: h.placement == 1
                                  ? AppColors.gold.withValues(alpha: 0.12)
                                  : Colors.black26,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '#${h.placement}',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    color: h.placement == 1
                                        ? AppColors.gold
                                        : Colors.white70,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${h.color} player',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                      Text(h.playedAt.split('.').first,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.white
                                                  .withValues(alpha: 0.45))),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('+${h.coinsEarned} coins',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.goldLight)),
                                    Text('+${h.xpEarned} XP',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white
                                                .withValues(alpha: 0.6))),
                                  ],
                                ),
                              ],
                            ),
                          ),
                    ],
                    const SizedBox(height: 18),
                    PrimaryButton(
                      label: 'Log out',
                      onPressed: () async {
                        await context.read<AuthProvider>().logout();
                        if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.gold, size: 24),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withValues(alpha: 0.55))),
      ],
    );
  }
}
