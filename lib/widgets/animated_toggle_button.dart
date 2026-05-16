import 'package:flutter/material.dart';

class AnimatedToggleButton extends StatefulWidget {
  final bool isRunning;
  final VoidCallback onPressed;
  final double size;

  const AnimatedToggleButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
    this.size = 100,
  });

  @override
  State<AnimatedToggleButton> createState() => _AnimatedToggleButtonState();
}

class _AnimatedToggleButtonState extends State<AnimatedToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.isRunning) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(AnimatedToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = Colors.green;
    final inactiveColor = colorScheme.primary;
    final buttonColor = widget.isRunning ? activeColor : inactiveColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.isRunning ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: Material(
        color: buttonColor,
        shape: const CircleBorder(),
        elevation: 4,
        shadowColor: buttonColor.withValues(alpha: 0.5),
        child: InkWell(
          onTap: widget.onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.isRunning
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  key: ValueKey(widget.isRunning),
                  color: Colors.white,
                  size: widget.size * 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
