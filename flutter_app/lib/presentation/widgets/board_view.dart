import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../game/board_geometry.dart';
import '../../game/ludo_engine.dart';
import 'board_painter.dart';
import 'flame_burst.dart';
import 'pawn_token.dart';

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.tokens,
    required this.currentColor,
    required this.movable,
    this.onTokenTap,
    this.highlightCurrent = true,
    this.boardFx,
    this.landings = const {},
  });

  /// Map of color -> list of 4 positions (-1 base .. 57 home).
  final Map<String, List<int>> tokens;
  final String currentColor;
  final Set<int> movable;

  /// Relative positions the movable tokens would land on - ringed on the board
  /// so the player can see where a throw leads before committing.
  final Set<int> landings;

  /// (color, tokenIndex) -> tap
  final void Function(String color, int tokenIndex)? onTokenTap;
  final bool highlightCurrent;

  /// Latest visual event (kill flames / home sparkles).
  final BoardFx? boardFx;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  int? _lastFxId;
  final List<_ActiveBurst> _bursts = [];

  /// Must match the controller's per-cell hop interval so the arc and the
  /// next board update stay in step.
  static const Duration _hop = Duration(milliseconds: 105);

  void _consumeFx(double cell) {
    final fx = widget.boardFx;
    if (fx == null || fx.id == _lastFxId) return;
    _lastFxId = fx.id;
    _bursts.clear();
    for (final spot in fx.spots) {
      final center = BoardGeometry.tokenCenter(
        color: spot.color,
        pos: spot.pos,
        tokenIndex: spot.tokenIndex,
        cell: cell,
      );
      _bursts.add(_ActiveBurst(
        key: ValueKey('fx_${fx.id}_${spot.color}_${spot.tokenIndex}'),
        center: center,
        style: fx.kind == FxKind.flame ? FxStyle.flame : FxStyle.sparkle,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Gold-lipped frame around the playing grid.
        const framePad = 9.0;
        final outer = constraints.biggest.shortestSide;
        final side = outer - framePad * 2;
        final cell = side / BoardGeometry.gridSize;

        _consumeFx(cell);

        final tokens = widget.tokens;
        final entries = <_TokenEntry>[];
        tokens.forEach((color, positions) {
          for (var i = 0; i < positions.length; i++) {
            final center = BoardGeometry.tokenCenter(
              color: color,
              pos: positions[i],
              tokenIndex: i,
              cell: cell,
            );
            entries.add(_TokenEntry(color, i, center));
          }
        });

        // Fan out tokens that share a spot so none hides behind another.
        final grouped = <String, List<_TokenEntry>>{};
        for (final e in entries) {
          final key = '${e.center.dx.toStringAsFixed(1)}:'
              '${e.center.dy.toStringAsFixed(1)}';
          grouped.putIfAbsent(key, () => []).add(e);
        }
        for (final group in grouped.values) {
          if (group.length <= 1) continue;
          final spread = cell * 0.24;
          for (var i = 0; i < group.length; i++) {
            final angle = 2 * math.pi * i / group.length - math.pi / 2;
            group[i].center = Offset(
              group[i].center.dx + spread * math.cos(angle),
              group[i].center.dy + spread * math.sin(angle),
            );
          }
        }

        return Container(
          width: outer,
          height: outer,
          padding: const EdgeInsets.all(framePad),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2C4A86), Color(0xFF0F1830)],
            ),
            borderRadius: BorderRadius.circular(framePad * 2.6),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.65),
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 20,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: SizedBox(
            width: side,
            height: side,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardPainter(
                      activeColor:
                          widget.highlightCurrent ? widget.currentColor : null,
                    ),
                  ),
                ),
                for (final spot in _landingSpots(cell))
                  _LandingHalo(
                    key: ValueKey(
                        'land_${widget.currentColor}_${spot.dx}_${spot.dy}'),
                    center: spot,
                    size: cell,
                    color: BoardPainter.colorOf(widget.currentColor),
                  ),
                for (final e in entries) _token(e, cell),
                for (final burst in _bursts)
                  Positioned(
                    key: burst.key,
                    left: burst.center.dx - cell * 1.1,
                    top: burst.center.dy - cell * 1.1,
                    width: cell * 2.2,
                    height: cell * 2.2,
                    child: FlameBurst(
                      size: cell * 2.2,
                      style: burst.style,
                      onFinished: () => _removeBurst(burst.key),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Centres of the squares the current throw can reach. Two tokens that can
  /// land on the same square get one ring - stacked halos on one square just
  /// look like a rendering bug.
  List<Offset> _landingSpots(double cell) {
    final seen = <int>{};
    final spots = <Offset>[];
    for (final pos in widget.landings) {
      final c = BoardGeometry.tokenCenter(
        color: widget.currentColor,
        pos: pos,
        // Landings are never in a yard, so the slot index cannot shift them.
        tokenIndex: 0,
        cell: cell,
      );
      final key = (c.dx * 4).round() * 100000 + (c.dy * 4).round();
      if (seen.add(key)) spots.add(c);
    }
    return spots;
  }

  void _removeBurst(Key key) {
    if (!mounted) return;
    setState(() {
      _bursts.removeWhere((b) => b.key == key);
    });
  }

  Widget _token(_TokenEntry entry, double cell) {
    final color = BoardPainter.colorOf(entry.color);
    final isMine = entry.color == widget.currentColor;
    final canMove = isMine && widget.movable.contains(entry.tokenIndex);
    final size = cell * 0.86;

    return _HoppingToken(
      key: ValueKey('${entry.color}_${entry.tokenIndex}'),
      center: entry.center,
      size: size,
      color: color,
      glowing: canMove,
      duration: _hop,
      onTap: canMove && widget.onTokenTap != null
          ? () => widget.onTokenTap!(entry.color, entry.tokenIndex)
          : null,
      pulse: canMove,
    );
  }
}

/// Animates a pawn from where it was to where the engine just put it, adding
/// the little arc + squash that makes a move read as a hop rather than a slide.
class _HoppingToken extends StatefulWidget {
  const _HoppingToken({
    super.key,
    required this.center,
    required this.size,
    required this.color,
    required this.glowing,
    required this.duration,
    this.onTap,
    this.pulse = false,
  });

  final Offset center;
  final double size;
  final Color color;

  /// Gold halo + rim while the token is a legal target.
  final bool glowing;
  final Duration duration;
  final VoidCallback? onTap;

  /// Heartbeat halo while the token is a legal target.
  final bool pulse;

  @override
  State<_HoppingToken> createState() => _HoppingTokenState();
}

class _HoppingTokenState extends State<_HoppingToken>
    with TickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  late final Animation<double> _pulseScale =
      Tween<double>(begin: 0.93, end: 1.09).animate(
    CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
  );

  Offset _from = Offset.zero;
  Offset _current = Offset.zero;
  bool _started = false;
  bool _teleport = false;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.center;
    _from = widget.center;
    _hop.addListener(_tick);
    if (widget.pulse) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _HoppingToken oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _hop.duration = widget.duration;
    }
    if (widget.center != oldWidget.center) {
      _from = _current;
      _started = true;
      // A token cut on the track is yanked back to its yard - arc that and it
      // would sail backwards across the board, so jump it flat instead.
      _teleport = (_current - widget.center).distance >
          (widget.size + widget.size) * 1.5;
      _hop.forward(from: 0);
    }
    if (widget.pulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.pulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  void _tick() {
    final raw = _hop.value;
    // Rise fast, land soft.
    final eased = Curves.easeOutCubic.transform(raw);
    setState(() {
      _t = raw;
      _current = Offset.lerp(_from, widget.center, eased)!;
    });
  }

  @override
  void dispose() {
    _hop
      ..removeListener(_tick)
      ..dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arc = _started && !_teleport ? math.sin(_t * math.pi) : 0.0;
    final size = widget.size;
    final scale = 1.0 + arc * 0.10;

    // footRatio is where the painted pawn meets the ground inside its box.
    const footRatio = PawnToken.heightRatio;

    // Seat the pawn slightly below the square's centre so it reads as standing
    // in the cell rather than floating above it - while keeping the foot
    // inside the recessed cradle painted in the yard.
    const seatDrop = 0.26;

    // The pawn raises itself off the board via PawnToken.hop so its shadow
    // stays planted; only the squash and the drift live out here.
    Widget pawn = PawnToken(
      size: size,
      color: widget.color,
      glowing: widget.glowing,
      hop: arc,
    );
    if (widget.onTap != null) {
      // The detector wraps the painted pawn (not the whole slot) so a tall hit
      // area never steals taps meant for the token in the row above.
      pawn = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: pawn,
      );
    }

    Widget body = Transform.translate(
      offset: Offset(
        _current.dx - size / 2,
        _current.dy - size * footRatio + size * seatDrop,
      ),
      child: Transform.scale(
        scale: scale,
        // Keep the feet pinned while the body stretches on the way up.
        child: Transform.translate(
          offset: Offset(0, size * footRatio * (1 - scale)),
          child: pawn,
        ),
      ),
    );

    if (widget.pulse) {
      body = ScaleTransition(scale: _pulseScale, child: body);
    }

    return Positioned(
      left: 0,
      top: 0,
      width: size,
      height: size * (footRatio + 0.1),
      child: body,
    );
  }
}

class _TokenEntry {
  _TokenEntry(this.color, this.tokenIndex, this.center);

  final String color;
  final int tokenIndex;
  Offset center;
}

/// Breathing ring on a square the current throw can reach.
class _LandingHalo extends StatefulWidget {
  const _LandingHalo({
    super.key,
    required this.center,
    required this.size,
    required this.color,
  });

  final Offset center;
  final double size;
  final Color color;

  @override
  State<_LandingHalo> createState() => _LandingHaloState();
}

class _LandingHaloState extends State<_LandingHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 760),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.center.dx - widget.size,
      top: widget.center.dy - widget.size,
      width: widget.size * 2,
      height: widget.size * 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_controller.value);
            return CustomPaint(
              painter: _LandingHaloPainter(
                color: widget.color,
                pulse: t,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LandingHaloPainter extends CustomPainter {
  _LandingHaloPainter({required this.color, required this.pulse});

  final Color color;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 2; // half-extent == one board cell
    final center = Offset(size.width / 2, size.height / 2);

    // Soft coloured wash so the square reads as "goes here" at a glance.
    canvas.drawCircle(
      center,
      s * (0.86 + pulse * 0.06),
      Paint()
        ..color = color.withValues(alpha: 0.18 + pulse * 0.14)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.10),
    );
    // Crisp ring.
    canvas.drawCircle(
      center,
      s * (0.72 + pulse * 0.10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * (0.09 + pulse * 0.05)
        ..color = Colors.white.withValues(alpha: 0.55 + pulse * 0.45),
    );
    canvas.drawCircle(
      center,
      s * (0.72 + pulse * 0.10),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.05
        ..color = Color.lerp(color, Colors.white, pulse * 0.6)!
            .withValues(alpha: 0.95),
    );
    // Four corner ticks - reads as a target marker, not a glow blob.
    for (var i = 0; i < 4; i++) {
      final a = math.pi / 4 + i * math.pi / 2;
      final dir = Offset(math.cos(a), math.sin(a));
      final from = center + dir * (s * 0.86);
      final to = center + dir * (s * 1.0);
      canvas.drawLine(
        from,
        to,
        Paint()
          ..strokeWidth = s * 0.07
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.5 + pulse * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LandingHaloPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.color != color;
}

class _ActiveBurst {
  const _ActiveBurst({
    required this.key,
    required this.center,
    required this.style,
  });

  final Key key;
  final Offset center;
  final FxStyle style;
}
