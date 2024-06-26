import 'package:flutter/material.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';
import 'package:go_router/go_router.dart';

import '../../../Backend/logging_wrappers.dart';
import '../../../constants.dart';
import '../../../gen/assets.gen.dart';
import '../../Widgets/lottie_lazy_load.dart';

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
        title: LottieLazyLoad(
          asset: Assets.tailcostickers.tailCoStickersFile144834344,
          width: 80,
        ),
        onCancelled: () => context.pop(),
        onUnlocked: () async {
          HiveProxy.put(settings, showDebugging, true);
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
