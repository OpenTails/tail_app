import 'package:flutter/material.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../../../constants.dart';

class DeveloperPincode extends StatefulWidget {
  const DeveloperPincode({super.key});

  @override
  State<DeveloperPincode> createState() => _DeveloperPincodeState();
}

class _DeveloperPincodeState extends State<DeveloperPincode> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenLock(
        title: Lottie.asset(
          renderCache: RenderCache.raster,
          width: 80,
          'assets/tailcostickers/tgs/TailCoStickers_file_144834344.tgs',
          decoder: LottieComposition.decodeGZip,
        ),
        onCancelled: () => context.pop(),
        onUnlocked: () {
          SentryHive.box(settings).put(showDebugging, true);
          context.pop();
        },
        // One at top left, 9 at bottom right
        correctString: '0476',
        keyPadConfig: const KeyPadConfig(
          // 0 - 9
          displayStrings: ['🦊', '🐶', '🐵', '🐦', '🐉', '🐎', '🦖', '🦦', '🐿️', '🐭'],
        ),
        cancelButton: const Icon(Icons.close),
        deleteButton: const Icon(Icons.delete),
      ),
    );
  }
}
