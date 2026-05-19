import 'package:flutter/material.dart';

class ExpressiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double borderRadius;

  const ExpressiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.borderRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.surfaceContainerLow;

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: effectiveColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: card,
      );
    }

    return card;
  }
}

class ExpressiveIconContainer extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double size;
  final double iconSize;
  final bool filled;

  const ExpressiveIconContainer({
    super.key,
    required this.icon,
    this.color,
    this.size = 48,
    this.iconSize = 24,
    this.filled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled
            ? effectiveColor.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(size / 3),
        border: filled
            ? null
            : Border.all(color: effectiveColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Center(
        child: Icon(
          icon,
          size: iconSize,
          color: effectiveColor,
        ),
      ),
    );
  }
}

class ExpressiveSectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const ExpressiveSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          ExpressiveIconContainer(
            icon: icon,
            size: 32,
            iconSize: 16,
            filled: false,
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class LatencyIndicator extends StatelessWidget {
  final int latencyMs;
  final bool showLabel;
  final double size;

  const LatencyIndicator({
    super.key,
    required this.latencyMs,
    this.showLabel = true,
    this.size = 16,
  });

  Color _getLatencyColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (latencyMs < 0) return colorScheme.error;
    if (latencyMs < 50) return Colors.green;
    if (latencyMs < 100) return Colors.orange;
    return colorScheme.error;
  }

  IconData _getLatencyIcon() {
    if (latencyMs < 0) return Icons.signal_wifi_off_rounded;
    if (latencyMs < 50) return Icons.speed_rounded;
    if (latencyMs < 100) return Icons.slow_motion_video_rounded;
    return Icons.network_ping_rounded;
  }

  String _formatLatency() {
    if (latencyMs < 0) return 'N/A';
    return '${latencyMs}ms';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getLatencyColor(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getLatencyIcon(),
          size: size,
          color: color,
        ),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(
            _formatLatency(),
            style: TextStyle(
              color: color,
              fontSize: size * 0.75,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class ExpressiveChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final Color? color;

  const ExpressiveChip({
    super.key,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.onDelete,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = color ?? colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected
            ? effectiveColor.withValues(alpha: 0.15)
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: onDelete != null ? 12 : 16,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: effectiveColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: selected ? effectiveColor : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                if (onDelete != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ExpressiveToggleButton extends StatefulWidget {
  final bool isActive;
  final VoidCallback onPressed;
  final String activeLabel;
  final String inactiveLabel;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const ExpressiveToggleButton({
    super.key,
    required this.isActive,
    required this.onPressed,
    this.activeLabel = 'STOP',
    this.inactiveLabel = 'START',
    this.activeIcon = Icons.stop_rounded,
    this.inactiveIcon = Icons.play_arrow_rounded,
  });

  @override
  State<ExpressiveToggleButton> createState() => _ExpressiveToggleButtonState();
}

class _ExpressiveToggleButtonState extends State<ExpressiveToggleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            color: widget.isActive
                ? colorScheme.errorContainer
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: (widget.isActive
                        ? colorScheme.error
                        : colorScheme.primary)
                    .withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Row(
              key: ValueKey(widget.isActive),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isActive ? widget.activeIcon : widget.inactiveIcon,
                  size: 28,
                  color: widget.isActive
                      ? colorScheme.onErrorContainer
                      : colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 12),
                Text(
                  widget.isActive ? widget.activeLabel : widget.inactiveLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: widget.isActive
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}