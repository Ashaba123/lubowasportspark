import 'package:flutter/material.dart';

enum AppScreenSize {
  small,
  medium,
  large,
}

class AppResponsiveBreakpoints {
  static const double smallMaxWidth = 599;
  static const double mediumMaxWidth = 1023;
  static const double mediumContentMaxWidth = 840;
  static const double largeContentMaxWidth = 1080;
  static AppScreenSize resolveScreenSize(double width) {
    if (width <= smallMaxWidth) {
      return AppScreenSize.small;
    }
    if (width <= mediumMaxWidth) {
      return AppScreenSize.medium;
    }
    return AppScreenSize.large;
  }
  static double resolveContentMaxWidth(AppScreenSize screenSize) {
    if (screenSize == AppScreenSize.medium) {
      return mediumContentMaxWidth;
    }
    if (screenSize == AppScreenSize.large) {
      return largeContentMaxWidth;
    }
    return double.infinity;
  }
}

class ResponsiveAppFrame extends StatelessWidget {
  const ResponsiveAppFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final Size viewportSize = MediaQuery.sizeOf(context);
    final AppScreenSize screenSize = AppResponsiveBreakpoints.resolveScreenSize(
      viewportSize.width,
    );
    final double maxWidth = AppResponsiveBreakpoints.resolveContentMaxWidth(
      screenSize,
    );
    if (screenSize == AppScreenSize.small) {
      return child;
    }
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
