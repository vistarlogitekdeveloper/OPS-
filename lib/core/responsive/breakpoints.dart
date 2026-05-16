import 'package:flutter/widgets.dart';

/// Breakpoints chosen to match common device classes. Values are the
/// **minimum** width at which the named class begins.
class Breakpoints {
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double wide = 1440;
}

enum ScreenSize { mobile, tablet, desktop, wide }

ScreenSize screenSizeOf(double width) {
  if (width >= Breakpoints.wide) return ScreenSize.wide;
  if (width >= Breakpoints.desktop) return ScreenSize.desktop;
  if (width >= Breakpoints.tablet) return ScreenSize.tablet;
  return ScreenSize.mobile;
}

extension ScreenSizeContext on BuildContext {
  ScreenSize get screenSize => screenSizeOf(MediaQuery.sizeOf(this).width);
  bool get isMobile => screenSize == ScreenSize.mobile;
  bool get isTabletOrLarger => screenSize.index >= ScreenSize.tablet.index;
  bool get isDesktopOrLarger => screenSize.index >= ScreenSize.desktop.index;
}

/// Picks one of the supplied values for the current breakpoint, falling back
/// down to mobile if a larger one isn't supplied.
T responsive<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
  T? wide,
}) {
  switch (context.screenSize) {
    case ScreenSize.wide:
      return wide ?? desktop ?? tablet ?? mobile;
    case ScreenSize.desktop:
      return desktop ?? tablet ?? mobile;
    case ScreenSize.tablet:
      return tablet ?? mobile;
    case ScreenSize.mobile:
      return mobile;
  }
}
