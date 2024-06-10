import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

import '../translation_string_definitions.dart';

part 'snack_bar_overlay.g.dart';

@Riverpod()
class SnackbarStream extends _$SnackbarStream {
  final StreamController<SnackBar> _streamController = StreamController();

  @override
  Stream<SnackBar> build() => _streamController.stream;

  void add(SnackBar content) => _streamController.add(content);
}

class SnackBarOverlay extends ConsumerWidget {
  const SnackBarOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<SnackBar> value = ref.watch(snackbarStreamProvider);
    Map<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    ref.listen(
      knownDevicesProvider,
      (previous, next) {
        if (previous != null && previous.length < next.length) {
          Future(
            () => ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  /// need to set following properties for best effect of awesome_snackbar_content
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.transparent,
                  content: AwesomeSnackbarContent(
                    title: newGearConnectedSnackbarTitle(),
                    message: newGearConnectedSnackbarLabel(),

                    /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
                    contentType: ContentType.success,
                  ),
                ),
              ),
          );
        }
      },
    );
    if (value.hasValue) {
      Future(
        () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              value.value!,
            );
        },
      );
    }
    if (knownDevices.isEmpty) {
      return child;
    }
    return MultiValueListenableBuilder(
      valueListenables: knownDevices.values
          .map(
            (e) => e.hasUpdate,
          )
          .toList(),
      builder: (context, values, child) {
        if (values.any((element) => element == true)) {
          BaseStatefulDevice? baseStatefulDevice = knownDevices.values
              .where(
                (element) => element.hasUpdate.value,
              )
              .firstOrNull;
          if (baseStatefulDevice == null) {
            return child!;
          }
          Future(
            () => ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(
                SnackBar(
                  /// need to set following properties for best effect of awesome_snackbar_content
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.transparent,
                  duration: const Duration(seconds: 30),
                  content: AwesomeSnackbarContent(
                    title: otaAvailableSnackbarTitle(),
                    message: otaAvailableSnackbarLabel(),
                    onPressed: () {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      return context.push("/ota", extra: baseStatefulDevice.baseStoredDevice.btMACAddress);
                    },

                    /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
                    contentType: ContentType.warning,
                  ),
                ),
              ),
          );
        }
        return child!;
      },
      child: child,
    );
  }
}
