import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/shop_repository.dart';
import '../../game/board_geometry.dart';
import '../../game/game_controller.dart';
import '../../injection_container.dart' as di;
import '../../logic/providers/auth_provider.dart';
import '../screens/leaderboard_screen.dart';
import '../screens/online/rooms_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/shop_screen.dart';
import '../widgets/logo_widget.dart';
import '../widgets/menu_button.dart';
import '../widgets/stat_chip.dart';
import 'auth/login_screen.dart';
import 'game/local_game_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  String? _announcement;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      lowerBound: 0.96,
      upperBound: 1.04,
    )..repeat(reverse: true);
    _fetchAnnouncement();
  }

  Future<void> _fetchAnnouncement() async {
    try {
      final config = await di.sl<ConfigRepository>().appConfig();
      if (!mounted) return;
      setState(() => _announcement = config.announcement);
    } catch (_) {
      // Server unreachable - the banner simply stays hidden.
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _requireAuth(VoidCallback action) {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      action();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _bubble(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final UserModel? user = auth.user;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -60,
                child:
                    _bubble(180, AppColors.royalBlue.withValues(alpha: 0.25)),
              ),
              Positioned(
                bottom: 80,
                left: -70,
                child: _bubble(220, AppColors.navyLight.withValues(alpha: 0.5)),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _topBar(context, user),
                            if (_announcement != null &&
                                _announcement!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.gold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.gold
                                          .withValues(alpha: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.campaign,
                                        size: 17, color: AppColors.gold),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _announcement!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Center(
                              child: ScaleTransition(
                                scale: _pulse,
                                child: Container(
                                  padding: const EdgeInsets.all(26),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  child: const LogoWidget(size: 62),
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                MenuButton(
                                  icon: Icons.smart_toy_outlined,
                                  label: AppStrings.playVsComputer,
                                  onTap: () => _startLocalFlow(vsCpu: true),
                                ),
                                const SizedBox(height: 14),
                                MenuButton(
                                  icon: Icons.people_outline,
                                  label: AppStrings.localMultiplayer,
                                  onTap: () => _startLocalFlow(vsCpu: false),
                                ),
                                const SizedBox(height: 14),
                                MenuButton(
                                  icon: Icons.public,
                                  label: AppStrings.onlineMultiplayer,
                                  onTap: () => _requireAuth(() =>
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const RoomsScreen()),
                                      )),
                                ),
                                const SizedBox(height: 14),
                                MenuButton(
                                  icon: Icons.meeting_room_outlined,
                                  label: AppStrings.privateRoom,
                                  onTap: () => _requireAuth(() =>
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => const RoomsScreen()),
                                      )),
                                ),
                              ],
                            ),
                            _bottomBar(context, user),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startLocalFlow({required bool vsCpu}) async {
    var count = 2;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.navyLight,
          title: Text(vsCpu ? 'CPU opponents' : 'Players'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final c in [2, 3, 4])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: ChoiceChip(
                    label: Text('$c'),
                    selected: count == c,
                    onSelected: (_) => setState(() => count = c),
                    selectedColor: AppColors.gold,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    _launchLocalGame(count, vsCpu: vsCpu);
  }

  void _launchLocalGame(int playerCount, {required bool vsCpu}) {
    // Ludo King rule: with two players they sit diagonally (Red vs Yellow).
    final colors = playerCount == 2
        ? ['red', 'yellow']
        : BoardGeometry.colors.take(playerCount).toList();
    final participants = <Participant>[];
    for (var i = 0; i < colors.length; i++) {
      if (vsCpu && i > 0) {
        participants.add(
            Participant(color: colors[i], name: 'CPU', isCpu: true));
      } else {
        participants.add(Participant(
          color: colors[i],
          name: vsCpu ? 'You' : 'P${i + 1}',
          isCpu: false,
        ));
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalGameScreen(participants: participants),
      ),
    );
  }

  Widget _topBar(BuildContext context, UserModel? user) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (user == null) {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            }
          },
          child: CircleAvatar(
            radius: 21,
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            child: Text(
              user == null ? '?' : user.avatar,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  user == null ? AppStrings.guest : user.username,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (user != null && user.username.startsWith('Guest')) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5)),
                  ),
                  child: const Text('GUEST',
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold)),
                ),
              ],
            ],
          ),
        ),
        StatChip(icon: Icons.monetization_on, value: '${user?.coins ?? 0}'),
        const SizedBox(width: 8),
        StatChip(icon: Icons.diamond_outlined, value: '${user?.gems ?? 0}'),
      ],
    );
  }

  Widget _bottomBar(BuildContext context, UserModel? user) {
    final labels = <String>[
      user == null ? AppStrings.signIn : AppStrings.profile,
      AppStrings.leaderboard,
      AppStrings.shop,
      AppStrings.settings,
    ];

    final icons = <IconData>[
      Icons.person_outline,
      Icons.leaderboard,
      Icons.shopping_bag_outlined,
      Icons.settings_outlined,
    ];

    final actions = <VoidCallback>[
      () {
        if (user != null) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        } else {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      },
      () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
          ),
      () => _requireAuth(() => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ShopScreen()),
          )),
      () => _snack(AppStrings.comingSoon),
    ];

    return Column(
      children: [
        Divider(color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (var i = 0; i < labels.length; i++)
              GestureDetector(
                onTap: actions[i],
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icons[i], size: 26, color: AppColors.gold),
                      const SizedBox(height: 5),
                      Text(labels[i], style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          AppStrings.version,
          style: TextStyle(
              fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
        ),
      ],
    );
  }
}
