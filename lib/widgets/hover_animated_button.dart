import 'package:flutter/material.dart';

/// 全站統一 Hover 懸停微動畫按鈕 (HoverAnimatedButton)
/// 提供質感微縮放、顏色漸變與滑鼠懸停效果
class HoverAnimatedButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? hoverColor;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final double hoverScale;
  final String? tooltip;

  const HoverAnimatedButton({
    super.key,
    required this.child,
    this.onPressed,
    this.backgroundColor,
    this.hoverColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
    this.hoverScale = 1.03,
    this.tooltip,
  });

  @override
  State<HoverAnimatedButton> createState() => _HoverAnimatedButtonState();
}

class _HoverAnimatedButtonState extends State<HoverAnimatedButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBgColor = widget.backgroundColor ?? theme.colorScheme.primary;
    final effectiveHoverColor = widget.hoverColor ?? effectiveBgColor.withOpacity(0.85);
    final effectiveBorderRadius = widget.borderRadius ?? BorderRadius.circular(12.0);

    Widget buttonCore = MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered && widget.onPressed != null ? widget.hoverScale : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _isHovered ? effectiveHoverColor : effectiveBgColor,
            borderRadius: effectiveBorderRadius,
            boxShadow: _isHovered && widget.onPressed != null
                ? [
                    BoxShadow(
                      color: (widget.backgroundColor ?? theme.colorScheme.primary).withOpacity(0.35),
                      blurRadius: 12.0,
                      spreadRadius: 1.0,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4.0,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: effectiveBorderRadius,
            child: widget.child,
          ),
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      return Tooltip(
        message: widget.tooltip!,
        child: buttonCore,
      );
    }

    return buttonCore;
  }
}
