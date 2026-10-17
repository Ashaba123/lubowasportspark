import 'package:flutter/widgets.dart';

/// Bottom padding so a scroll view's last item clears the floating nav bar and system insets.
/// MainShell uses `extendBody`, so inside a tab the bar's height arrives as MediaQuery bottom padding.
double bottomScrollInset(BuildContext context, [double extra = 16]) =>
    MediaQuery.paddingOf(context).bottom + extra;

/// Centers [child] when it fits and scrolls it when it does not (small phones, large text).
class ScrollableCenter extends StatelessWidget {
  const ScrollableCenter({super.key, required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets resolved = padding.copyWith(bottom: padding.bottom + bottomScrollInset(context, 0));
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) => SingleChildScrollView(
        padding: resolved,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (constraints.maxHeight - resolved.vertical).clamp(0, double.infinity)),
          child: Center(child: child),
        ),
      ),
    );
  }
}
