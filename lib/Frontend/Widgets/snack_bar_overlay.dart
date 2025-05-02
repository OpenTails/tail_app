import 'dart:async';

import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:multi_value_listenable_builder/multi_value_listenable_builder.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../go_router_config.dart';
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
  SnackBarOverlay({required this.child, super.key});

  final Map<String, bool> hasDisplayedNotice = {};
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<SnackBar> value = ref.watch(snackbarStreamProvider);
    BuiltMap<String, BaseStatefulDevice> knownDevices = ref.watch(knownDevicesProvider);
    ref.listen(
      knownDevicesProvider,
      (previous, next) {
        if (previous != null && previous.length < next.length) {
          ScaffoldMessenger.of(context)
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
            );
        }
      },
    );
    if (value.hasValue) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          value.value!,
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
              .where(
                (element) => hasDisplayedNotice.keys.contains(element.baseStoredDevice.btMACAddress),
              )
              .firstOrNull;
          if (baseStatefulDevice == null) {
            return child!;
          }
          hasDisplayedNotice[baseStatefulDevice.baseStoredDevice.btMACAddress] = true;
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(

                  /// need to set following properties for best effect of awesome_snackbar_content
                  elevation: 0,
                  behavior: SnackBarBehavior.floating,
                  backgroundColor: Colors.transparent,
                  content: InkWell(
                    child: AwesomeSnackbarContent(
                      title: otaAvailableSnackbarTitle(),
                      message: otaAvailableSnackbarLabel(),

                      /// change contentType to ContentType.success, ContentType.warning or ContentType.help for variants
                      contentType: ContentType.warning,
                    ),
                    onTap: () async {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      return OtaUpdateRoute(device: baseStatefulDevice.baseStoredDevice.btMACAddress).push(context);
                    },
                  )),
            );
        }
        return child!;
      },
      child: child,
    );
  }
}
