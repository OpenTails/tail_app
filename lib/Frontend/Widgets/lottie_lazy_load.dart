import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../constants.dart';

class LottieLazyLoad extends StatefulWidget {
  const LottieLazyLoad({
    super.key,
    required this.asset,
    this.renderCache = true,
    required this.width,
  });

  final String asset;
  final bool renderCache;
  final double width;

  @override
  State<LottieLazyLoad> createState() => _LottieLazyLoadState();
}

bool _enableAnimation = true;

/// Call before widget tests to disable lottie animations.
@visibleForTesting
void enableAnimations(bool enabled) {
  _enableAnimation = enabled;
}

class _LottieLazyLoadState extends State<LottieLazyLoad>
    with TickerProviderStateMixin {
  bool isLoaded = false;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedOpacity(
        opacity: _controller.isAnimating ? 1 : 0,
        duration: animationTransitionDuration,
        child: Lottie.asset(
          width: widget.width,
          renderCache: widget.renderCache ? RenderCache.raster : null,
          widget.asset,
          controller: _controller,
          onLoaded: (p0) {
            // Configure the AnimationController with the duration of the
            // Lottie file and start the animation.
            if (_enableAnimation) {
              _controller
                ..duration = p0.duration
                ..forward()
                ..addListener(() {
                  if (_controller.isCompleted && context.mounted) {
                    _controller.repeat();
                  }
                });
            } else {
              _controller.reset();
            }
            setState(() {
              isLoaded = true;
            });
          },
        ),
      ),
    );
  }
}
