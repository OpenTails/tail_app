import 'package:flutter/material.dart';
import 'package:lottie_native/lottie_native.dart';

import '../../constants.dart';

class LottieLazyLoad extends StatefulWidget {
  const LottieLazyLoad({super.key, required this.asset, required this.width});

  final String asset;
  final double width;

  @override
  State<LottieLazyLoad> createState() => _LottieLazyLoadState();
}

class _LottieLazyLoadState extends State<LottieLazyLoad> with TickerProviderStateMixin {
  bool isLoaded = false;
  LottieController? lottieController;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isLoaded ? 1 : 0,
      duration: animationTransitionDuration,
      child: SizedBox(
        width: widget.width,
        height: widget.width,
        child: LottieView.fromAsset(
          filePath: widget.asset,
          autoPlay: true,
          loop: true,
          onViewCreated: onViewCreated,
        ),
      ),
    );
  }

  void onViewCreated(LottieController lottieController) {
    this.lottieController = lottieController;
    setState(() {
      isLoaded = true;
    });
  }
}
