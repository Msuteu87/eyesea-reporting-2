import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/theme/app_colors.dart';

/// Animated heart button for thanking reports
class ThankYouButton extends StatefulWidget {
  final int count;
  final bool isThanked;
  final VoidCallback? onPressed;
  final bool enabled;

  const ThankYouButton({
    super.key,
    required this.count,
    required this.isThanked,
    this.onPressed,
    this.enabled = true,
  });

  @override
  State<ThankYouButton> createState() => _ThankYouButtonState();
}

class _ThankYouButtonState extends State<ThankYouButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(ThankYouButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate on thank change
    if (widget.isThanked != oldWidget.isThanked && widget.isThanked) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.enabled ? widget.onPressed : null,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  widget.isThanked ? LucideIcons.heart : LucideIcons.heart,
                  size: 24,
                  color: widget.isThanked
                      ? AppColors.punchRed
                      : (widget.enabled
                          ? (isDark ? Colors.grey[400] : Colors.grey[600])
                          : Colors.grey[400]),
                ),
              ),
              if (widget.isThanked)
                Container(
                  margin: const EdgeInsets.only(left: 2),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.punchRed,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                _formatCount(widget.count),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: widget.isThanked
                      ? AppColors.punchRed
                      : (isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
