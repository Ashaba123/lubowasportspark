import 'package:flutter/material.dart';

/// Animated loader using a rotating football icon instead of the default spinner.
class FootballLoader extends StatefulWidget {
  const FootballLoader({
    super.key,
    this.size = 32,
  });

  final double size;

  @override
  State<FootballLoader> createState() => _FootballLoaderState();
}

class _FootballLoaderState extends State<FootballLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: RotationTransition(
          turns: _controller,
          child: Icon(
            Icons.sports_soccer,
            size: widget.size,
            color: color,
          ),
        ),
      ),
    );
  }
}

