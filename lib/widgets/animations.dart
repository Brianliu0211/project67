import 'package:flutter/material.dart';
import '../services/app_settings.dart';

/// A reusable Shimmer loading block widget that creates a flowing gradient highlight effect.
class ShimmerLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Curated smooth dark/light slate grey palette with distinct contrast
    final Color baseColor = isDark ? const Color(0xFF1B1F27) : const Color(0xFFE2E2E2);
    final Color highlightColor = isDark ? const Color(0xFF2F3642) : const Color(0xFFF3F3F3);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-2.0 + _controller.value * 4, -0.3),
              end: Alignment(-1.0 + _controller.value * 4, 0.3),
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        );
      },
    );
  }
}

/// An animated card wrapper that handles mouse hover entry to scale up, tilt slightly, and glow.
class HoverAnimatedCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;

  const HoverAnimatedCard({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
  });

  @override
  State<HoverAnimatedCard> createState() => _HoverAnimatedCardState();
}

class _HoverAnimatedCardState extends State<HoverAnimatedCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppSettings.instance.primaryColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: _isHovered
            ? (Matrix4.identity()
              ..translate(0.0, -4.0, 0.0) // upward float
              ..scale(1.025))            // micro scale
            : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? primaryColor.withOpacity(isDark ? 0.35 : 0.18) // dynamic glow
                  : Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: _isHovered ? 16.0 : 8.0,
              spreadRadius: _isHovered ? 1.0 : 0.0,
              offset: _isHovered ? const Offset(0.0, 8.0) : const Offset(0.0, 2.0),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// A staggered entry animation wrapper that fades and slides widgets upward based on list index.
class StaggeredFadeIn extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delayStep;

  const StaggeredFadeIn({
    super.key,
    required this.child,
    required this.index,
    this.delayStep = const Duration(milliseconds: 60),
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.22), // start slightly lower
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    // Stagger start time based on element index
    Future.delayed(widget.delayStep * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
