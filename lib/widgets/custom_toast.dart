import 'package:flutter/material.dart';

enum ToastType { success, warning, error }

class CustomToast extends StatefulWidget {
  final String message;
  final ToastType type;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const CustomToast({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
    this.actionLabel,
    this.onActionPressed,
  });

  static void show(
    BuildContext context, 
    String message, 
    ToastType type, {
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    OverlayEntry? overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 24,
        right: MediaQuery.of(context).size.width >= 768 ? 24 : null,
        left: MediaQuery.of(context).size.width >= 768 ? null : 24,
        width: MediaQuery.of(context).size.width >= 768 ? 360 : MediaQuery.of(context).size.width - 48,
        child: CustomToast(
          message: message,
          type: type,
          actionLabel: actionLabel,
          onActionPressed: onActionPressed,
          onDismiss: () {
            try {
              overlayEntry?.remove();
              overlayEntry = null;
            } catch (_) {}
          },
        ),
      ),
    );
    Overlay.of(context).insert(overlayEntry!);
  }

  @override
  State<CustomToast> createState() => _CustomToastState();
}

class _CustomToastState extends State<CustomToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismiss();
        });
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
    Color borderColor;
    Color glowColor;
    IconData icon;
    Color iconColor;

    switch (widget.type) {
      case ToastType.success:
        borderColor = const Color(0xFF10B981);
        glowColor = const Color(0xFF10B981).withValues(alpha: 0.25);
        icon = Icons.check_circle_rounded;
        iconColor = const Color(0xFF10B981);
        break;
      case ToastType.warning:
        borderColor = const Color(0xFFF59E0B);
        glowColor = const Color(0xFFF59E0B).withValues(alpha: 0.25);
        icon = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFF59E0B);
        break;
      case ToastType.error:
        borderColor = const Color(0xFFEF4444);
        glowColor = const Color(0xFFEF4444).withValues(alpha: 0.25);
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFFEF4444);
        break;
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: glowColor,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
                if (widget.actionLabel != null && widget.onActionPressed != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      widget.onActionPressed!();
                      _controller.reverse().then((_) {
                        widget.onDismiss();
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.actionLabel!,
                      style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    _controller.reverse().then((_) {
                      widget.onDismiss();
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.close, color: Colors.white54, size: 16),
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
