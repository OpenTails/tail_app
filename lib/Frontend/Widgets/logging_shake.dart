import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:shake/shake.dart';

import '../../Backend/LoggingWrappers.dart';
import '../../constants.dart';

class LoggingShake extends StatefulWidget {
  const LoggingShake({super.key, required this.child});

  final Widget child;

  @override
  State<LoggingShake> createState() => _LoggingShakeState();
}

class _LoggingShakeState extends State<LoggingShake> {
  ShakeDetector? detector;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SentryHive.box(settings).listenable(keys: [showDebugging]),
      builder: (context, value, child) {
        bool enabled = HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault);
        if (enabled && detector == null) {
          detector = ShakeDetector.waitForStart(
            onPhoneShake: () {
              if (context.mounted) {
                context.push("/settings/developer/logs");
              } else {
                detector?.stopListening();
                detector = null;
              }
            },
          );
          detector?.startListening();
        } else {
          detector?.stopListening();
          detector = null;
        }

        return child!;
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();
    detector?.stopListening();
    detector = null;
  }
}
