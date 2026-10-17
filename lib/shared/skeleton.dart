import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

export 'package:skeletonizer/skeletonizer.dart' show Bone;

const Color _lightBone = Color(0xFFE6E9E6);
const Color _lightHighlight = Color(0xFFF6F8F6);
const Color _darkBone = Color(0xFF2E2E2E);
const Color _darkHighlight = Color(0xFF3C3C3C);

PaintingEffect _shimmer(Brightness b) => b == Brightness.dark
    ? const ShimmerEffect(baseColor: _darkBone, highlightColor: _darkHighlight)
    : const ShimmerEffect(baseColor: _lightBone, highlightColor: _lightHighlight);

PaintingEffect _solid(Brightness b) =>
    SolidColorEffect(color: b == Brightness.dark ? _darkBone : _lightBone);

/// App-wide skeleton colors. Follows the app theme (not platform brightness)
/// and drops the shimmer when the OS asks to reduce motion.
class AppSkeletonTheme extends StatelessWidget {
  const AppSkeletonTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SkeletonizerConfig(
      data: SkeletonizerConfigData(
        effectResolver: reduceMotion ? _solid : _shimmer,
        brightness: brightness,
      ),
      child: child,
    );
  }
}

/// Skeleton for content that has not loaded yet. Pass a layout filled with
/// fake data; the fake text is hidden from screen readers.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Loading',
      child: ExcludeSemantics(child: Skeletonizer(child: child)),
    );
  }
}

/// Sweeps a highlight across a busy button while keeping its color and label.
/// Blocks taps and focus while [active].
class ButtonShimmer extends StatefulWidget {
  const ButtonShimmer({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<ButtonShimmer> createState() => _ButtonShimmerState();
}

class _ButtonShimmerState extends State<ButtonShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ButtonShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final animate = widget.active && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    final shimmering = _controller.isAnimating
        ? AnimatedBuilder(
            animation: _controller,
            child: widget.child,
            builder: (context, child) {
              final t = _controller.value * 3 - 1;
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (rect) => LinearGradient(
                  begin: Alignment(t - 1, -0.3),
                  end: Alignment(t + 1, 0.3),
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.35),
                    Colors.white.withValues(alpha: 0),
                  ],
                  stops: const <double>[0.35, 0.5, 0.65],
                ).createShader(rect),
                child: child,
              );
            },
          )
        : widget.child;
    return IgnorePointer(child: ExcludeFocus(child: shimmering));
  }
}
