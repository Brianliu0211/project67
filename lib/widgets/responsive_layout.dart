import 'package:flutter/material.dart';

/// 響應式斷點常數與輔助類別
class ResponsiveBreakpoints {
  static const double mobileMax = 600.0;
  static const double tabletMax = 1024.0;
}

/// 擴充 BuildContext 方便快速判斷當前螢幕尺寸分類
extension ResponsiveContextExtension on BuildContext {
  /// 螢幕寬度 < 600px
  bool get isMobile =>
      MediaQuery.of(this).size.width < ResponsiveBreakpoints.mobileMax;

  /// 螢幕寬度在 600px 至 1024px 之間
  bool get isTablet {
    final width = MediaQuery.of(this).size.width;
    return width >= ResponsiveBreakpoints.mobileMax &&
        width < ResponsiveBreakpoints.tabletMax;
  }

  /// 螢幕寬度 >= 1024px
  bool get isDesktop =>
      MediaQuery.of(this).size.width >= ResponsiveBreakpoints.tabletMax;

  /// 依據當前裝置型態回傳對應值
  T responsiveValue<T>({
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    if (isMobile) return mobile;
    if (isTablet) return tablet ?? mobile;
    return desktop;
  }
}

/// 響應式組件包覆器 (自動依照 Mobile / Tablet / Desktop 切換對應 Widget)
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < ResponsiveBreakpoints.mobileMax) {
          return mobile;
        } else if (constraints.maxWidth < ResponsiveBreakpoints.tabletMax) {
          return tablet ?? mobile;
        } else {
          return desktop;
        }
      },
    );
  }
}
