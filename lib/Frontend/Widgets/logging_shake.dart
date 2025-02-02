import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/adapters.dart';
import 'package:shake/shake.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../go_router_config.dart';

class LoggingShake extends StatefulWidget {
  const LoggingShake({required this.child, super.key});

  final Widget child;

  @override
  State<LoggingShake> createState() => _LoggingShakeState();
}

class _LoggingShakeState extends State<LoggingShake> {
  ShakeDetector? detector;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box(settings).listenable(keys: [showDebugging]),
      builder: (context, value, child) {
        bool enabled = HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault);
        if (enabled && detector == null) {
          detector = ShakeDetector.waitForStart(
            onPhoneShake: () {
              if (context.mounted) {
                unawaited(const LogsRoute().push(context));
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
