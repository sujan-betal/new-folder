import 'package:flutter/material.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/network/api_client.dart';
import '../../core/network/token_storage.dart';
import '../../injection_container.dart' as di;
import '../../core/constants/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  static const _medals = ['\u{1F947}', '\u{1F948}', '\u{1F949}'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ApiClient(di.sl<TokenStorage>());
      final data = await client.get(ApiEndpoints.leaderboard);
      setState(() {
        _users = ((data as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
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
                    const Text('Ranking',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon:
                          const Icon(Icons.refresh, color: AppColors.gold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold))
                    : _error != null
                        ? Center(
                            child: Text(_error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13)),
                          )
                        : _users.isEmpty
                            ? const Center(
                                child: Text('No players ranked yet.'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(14),
                                itemCount: _users.length,
                                itemBuilder: (context, index) {
                                  final u = _users[index];
                                  final rank =
                                      (u['rank'] as num?)?.toInt() ?? index + 1;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: rank <= 3
                                          ? AppColors.gold
                                              .withValues(alpha: 0.12)
                                          : Colors.black26,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                          color: rank <= 3
                                              ? AppColors.gold
                                                  .withValues(alpha: 0.6)
                                              : Colors.white24),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 34,
                                          child: Text(
                                            rank <= 3
                                                ? _medals[rank - 1]
                                                : '#$rank',
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        CircleAvatar(
                                          radius: 17,
                                          backgroundColor:
                                              AppColors.royalBlue,
                                          child: Text((u['avatar'] ?? '')
                                                  .toString()
                                                  .isEmpty
                                              ? '\u{1F3B2}'
                                              : u['avatar'].toString()),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            (u['username'] ?? '?').toString(),
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w800),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text('Lvl ${(u['level'] as num?)?.toInt() ?? 1}',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.white60)),
                                            Text(
                                              '${(u['wins'] as num?)?.toInt() ?? 0} wins',
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.gold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
