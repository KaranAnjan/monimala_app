import 'package:flutter/material.dart';

OverlayEntry? _currentEntry;

void showHeartBubble(BuildContext context) {
  _currentEntry?.remove();

  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return;
  final position = box.localToGlobal(Offset.zero);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _HeartBubbleOverlay(
      position: position,
      size: box.size,
      color: Theme.of(context).colorScheme.primary,
      onRemove: () => entry.remove(),
    ),
  );
  _currentEntry = entry;
  Overlay.of(context).insert(entry);
}

class _HeartBubbleOverlay extends StatefulWidget {
  final Offset position;
  final Size size;
  final Color color;
  final VoidCallback onRemove;
  const _HeartBubbleOverlay({
    required this.position,
    required this.size,
    required this.color,
    required this.onRemove,
  });

  @override
  State<_HeartBubbleOverlay> createState() => _HeartBubbleOverlayState();
}

class _HeartBubbleOverlayState extends State<_HeartBubbleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onRemove();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final center = Offset(
      widget.position.dx + widget.size.width / 2 - 16,
      widget.position.dy - 10,
    );

    return Stack(
      children: [
        Positioned(
          left: center.dx,
          top: center.dy,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              double scale;
              double opacity;
              double translateY;

              if (t < 0.35) {
                final p = t / 0.35;
                scale = 0.0 + p * 1.3;
                opacity = 1.0;
                translateY = 0.0;
              } else if (t < 0.55) {
                final p = (t - 0.35) / 0.2;
                scale = 1.3 - p * 0.3;
                opacity = 1.0;
                translateY = 0.0;
              } else {
                final p = (t - 0.55) / 0.45;
                scale = 1.0;
                opacity = 1.0 - p;
                translateY = -40.0 * p;
              }

              return Transform.translate(
                offset: Offset(0, translateY),
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Icon(Icons.favorite, color: widget.color, size: 32),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
