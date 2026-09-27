import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/deep_link.dart';
import '../../../data/models/room_model.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../injection_container.dart' as di;
import '../../../logic/providers/auth_provider.dart';
import '../../../logic/providers/room_provider.dart';
import '../../widgets/primary_button.dart';
import 'online_game_screen.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => di.sl<RoomProvider>()..loadOpenRooms(),
      child: const _RoomsBody(),
    );
  }
}

class _RoomsBody extends StatefulWidget {
  const _RoomsBody();

  @override
  State<_RoomsBody> createState() => _RoomsBodyState();
}

class _RoomsBodyState extends State<_RoomsBody> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _createRoom(RoomProvider rooms) async {
    final nameController = TextEditingController(text: 'My Room');
    var maxPlayers = 4;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.navyLight,
          title: const Text('Create room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Room name'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Players'),
                  const Spacer(),
                  for (final count in [2, 3, 4])
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text('$count'),
                        selected: maxPlayers == count,
                        onSelected: (_) => setState(() => maxPlayers = count),
                        selectedColor: AppColors.gold,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (created == true && mounted) {
      final ok = await rooms.createRoom(
        name: nameController.text.trim().isEmpty
            ? 'My Room'
            : nameController.text.trim(),
        maxPlayers: maxPlayers,
      );
      if (ok && mounted) _openWaiting();
    }
  }

  Future<void> _joinByCode(RoomProvider rooms) async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a 6-character room code')),
      );
      return;
    }
    final ok = await rooms.join(code);
    if (ok && mounted) _openWaiting();
  }

  Future<void> _joinRoom(RoomProvider rooms, RoomModel target) async {
    final ok = await rooms.join(target.code);
    if (ok && mounted) _openWaiting();
  }

  void _openWaiting() {
    final code = context.read<RoomProvider>().room?.code;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => WaitingRoomScreen(roomCode: code),
          ),
        )
        .then((_) {
          if (mounted) context.read<RoomProvider>().loadOpenRooms();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomProvider>(
      builder: (context, rooms, _) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: rooms.loadOpenRooms,
              color: AppColors.gold,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                      const Text('Online Rooms',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _codeController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          style: const TextStyle(letterSpacing: 3),
                          decoration: const InputDecoration(
                            counterText: '',
                            labelText: 'Room code',
                            hintText: 'ABC123',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _joinByCode(rooms),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: AppColors.goldGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Join',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF4A2C00))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'Create new room',
                    onPressed: () => _createRoom(rooms),
                  ),
                  if (rooms.error != null) ...[
                    const SizedBox(height: 10),
                    Text(rooms.error!,
                        style:
                            const TextStyle(color: AppColors.red, fontSize: 13)),
                  ],
                  const SizedBox(height: 22),
                  Text('Open rooms',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (rooms.loading && rooms.openRooms.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(28),
                      child: Center(
                          child: CircularProgressIndicator(color: AppColors.gold)),
                    )
                  else if (rooms.openRooms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No open rooms right now.\nCreate one and share the code!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55)),
                      ),
                    )
                  else
                    for (final r in rooms.openRooms)
                      _RoomTile(
                        room: r,
                        onJoin: r.isFull ? null : () => _joinRoom(rooms, r),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  const _RoomTile({required this.room, this.onJoin});

  final RoomModel room;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              room.code,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text('${room.players.length}/${room.maxPlayers} players',
                    style: TextStyle(
                        fontSize: 12, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF4A2C00),
            ),
            child: Text(room.isFull ? 'Full' : 'Join'),
          ),
        ],
      ),
    );
  }
}

class WaitingRoomScreen extends StatefulWidget {
  const WaitingRoomScreen({super.key, this.roomCode});

  /// Room code to attach to. Null when entering from create/join where the
  /// RoomProvider already holds the room.
  final String? roomCode;

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen> {
  late final RoomProvider _provider = di.sl<RoomProvider>();
  Timer? _fallback;
  bool _leaving = false;
  bool _navigating = false;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _provider.onClosed = _handleClosed;
    _provider.onGameStarted = _handleGameStarted;

    final code = widget.roomCode;
    if (code != null && code.isNotEmpty) {
      _provider.attach(code);
    }

    // Safety net polling only kicks in when the socket is unavailable; on a
    // healthy connection the realtime pushes drive everything.
    _fallback = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _provider.room == null) return;
      await _provider.refresh();
    });
  }

  @override
  void dispose() {
    _fallback?.cancel();
    _provider.disconnect();
    super.dispose();
  }

  void _handleClosed() {
    if (!mounted || _leaving || _navigating) return;
    _leaving = true;
    _fallback?.cancel();
    Navigator.of(context).pop();
  }

  /// Every seated player is pushed straight into the game the moment the host
  /// presses start - nobody is left waiting in the lobby.
  void _handleGameStarted(int gameId) {
    if (!mounted || _navigating || _leaving) return;
    _navigating = true;
    _fallback?.cancel();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OnlineGameScreen(gameId: gameId)),
    );
  }

  Future<void> _leave() async {
    if (_leaving || _navigating) return;
    _leaving = true;
    _fallback?.cancel();
    await _provider.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copyCode() async {
    final room = _provider.room;
    if (room == null) return;
    await Clipboard.setData(ClipboardData(text: room.code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Room code copied - share it with a friend!')));
  }

  Future<void> _invite() async {
    final room = _provider.room;
    if (room == null || _sharing) return;
    _sharing = true;
    try {
      final link = DeepLink.room(room.code);
      await SharePlus.instance.share(ShareParams(
        subject: 'Join my Ludo room!',
        text: 'Join my Ludo Master room\nCode: ${room.code}\n'
            'Tap the link to open the app and jump in! $link',
      ));
    } catch (_) {
    } finally {
      _sharing = false;
    }
  }

  Future<void> _startGame() async {
    final room = _provider.room;
    if (room == null || _navigating) return;
    _navigating = true;
    _fallback?.cancel();
    try {
      final gameRepo = di.sl<GameRepository>();
      final game =
          await gameRepo.start(mode: 'online', roomCode: room.code);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OnlineGameScreen(gameId: game.id)),
      );
    } catch (e) {
      _navigating = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.watch<AuthProvider>().user?.id ?? -1;

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<RoomProvider>(builder: (context, rooms, _) {
        final room = rooms.room;
        final isHost = room?.hostId == myId;
        final canStart = room != null && room.players.length >= 2;

        return Scaffold(
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.backgroundGradient),
            child: SafeArea(
              child: room == null
                  ? Center(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.gold),
                        const SizedBox(height: 12),
                        Text(rooms.error ?? 'Joining room...',
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: _leave,
                          child: const Text('Go back'),
                        ),
                      ],
                    ))
                  : Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _leave,
                                icon: const Icon(Icons.arrow_back_ios_new,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(room.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.gold, width: 1.4),
                            ),
                            child: Column(
                              children: [
                                Text('ROOM CODE',
                                    style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 3,
                                        color: Colors.white
                                            .withValues(alpha: 0.6))),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: _copyCode,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            room.code,
                                            style: const TextStyle(
                                                fontSize: 30,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 8,
                                                color: AppColors.gold),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.copy_rounded,
                                              size: 18, color: Colors.white70),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Text('tap to copy',
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.white38)),
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: _invite,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 9),
                                    decoration: BoxDecoration(
                                      gradient: AppColors.goldGradient,
                                      borderRadius: BorderRadius.circular(22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.goldDark
                                              .withValues(alpha: 0.45),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.ios_share,
                                            size: 18,
                                            color: Color(0xFF4A2C00)),
                                        SizedBox(width: 8),
                                        Text('Invite friends',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF4A2C00))),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.7,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: room.maxPlayers,
                              itemBuilder: (context, index) {
                                if (index < room.players.length) {
                                  final p = room.players[index];
                                  final isMe = p.userId == myId;
                                  return _SeatCard(
                                    username: isMe
                                        ? '${p.username} (You)'
                                        : p.username +
                                            (p.userId == room.hostId
                                                ? ' (Host)'
                                                : ''),
                                    avatar: p.avatar.isEmpty
                                        ? '\u{1F3B2}'
                                        : p.avatar,
                                    colorName: p.color,
                                    ready: p.isReady,
                                    pulse: isMe,
                                  );
                                }
                                return const _SeatCard(username: 'Waiting...');
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          PrimaryButton(
                            label: isHost
                                ? (canStart ? 'Start Game' : 'Need 2+ players')
                                : (room.players.any(
                                        (p) => p.userId == myId && p.isReady)
                                    ? 'Not Ready'
                                    : 'Ready'),
                            onPressed: !isHost
                                ? rooms.toggleReady
                                : canStart
                                    ? _startGame
                                    : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isHost
                                ? (canStart
                                    ? 'Everyone joined - start when ready!'
                                    : 'Invite friends with the button above!')
                                : 'Host starts the game when everyone is set.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.55)),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }
}

class _SeatCard extends StatefulWidget {
  const _SeatCard({
    required this.username,
    this.avatar,
    this.colorName,
    this.ready,
    this.pulse = false,
  });

  final String username;
  final String? avatar;
  final String? colorName;
  final bool? ready;
  final bool pulse;

  @override
  State<_SeatCard> createState() => _SeatCardState();
}

class _SeatCardState extends State<_SeatCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    lowerBound: 0.97,
    upperBound: 1.03,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SeatCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !oldWidget.pulse) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulse && oldWidget.pulse) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.colorName == null
        ? Colors.grey.shade700
        : BoardColorHelper.of(widget.colorName!);
    final card = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.ready == true ? AppColors.gold : Colors.white24,
          width: widget.ready == true ? 1.6 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              CircleAvatar(
                  radius: 15,
                  backgroundColor: color,
                  child: Text(widget.avatar ?? '')),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (widget.ready != null)
            Text(
              widget.ready! ? 'READY \u2714' : 'not ready',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: widget.ready! ? AppColors.gold : Colors.white38),
            )
          else
            Text('- empty seat -',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.35))),
        ],
      ),
    );
    return widget.pulse
        ? ScaleTransition(scale: _pulse, child: card)
        : card;
  }
}

class BoardColorHelper {
  BoardColorHelper._();

  static Color of(String name) {
    switch (name) {
      case 'red':
        return AppColors.red;
      case 'green':
        return AppColors.green;
      case 'yellow':
        return AppColors.yellow;
      case 'blue':
        return AppColors.blue;
      default:
        return Colors.grey;
    }
  }
}
