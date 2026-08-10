import 'package:flutter/material.dart';

/// 全站統一對話框容器
/// 解決對話框輸入法跳出、字數變動或狀態更新時產生的畫面擠壓與抽動問題 (Jitter/Flicker Safeguard)
class BaseDialogContainer extends StatelessWidget {
  final String title;
  final IconData? titleIcon;
  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final double maxHeightRatio;
  final EdgeInsetsGeometry contentPadding;

  const BaseDialogContainer({
    super.key,
    required this.title,
    this.titleIcon,
    required this.child,
    this.actions,
    this.maxWidth = 540.0,
    this.maxHeightRatio = 0.85,
    this.contentPadding = const EdgeInsets.all(20.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.of(context).size;
    final maxAllowedHeight = screenSize.height * maxHeightRatio;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: maxAllowedHeight,
          ),
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor.withOpacity(0.96),
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: theme.dividerColor.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 24.0,
                spreadRadius: 2.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 標頭 Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20.0)),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor.withOpacity(0.1),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    if (titleIcon != null) ...[
                      Icon(titleIcon, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '關閉',
                    ),
                  ],
                ),
              ),

              // 主體 Content (具備滾動保護)
              Flexible(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: contentPadding,
                  child: child,
                ),
              ),

              // 底部 Actions 按鈕區 (若有)
              if (actions != null && actions!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.3),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20.0)),
                    border: Border(
                      top: BorderSide(
                        color: theme.dividerColor.withOpacity(0.1),
                        width: 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
