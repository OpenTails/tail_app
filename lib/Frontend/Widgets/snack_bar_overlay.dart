import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'snack_bar_overlay.g.dart';

@Riverpod()
class SnackbarStream extends _$SnackbarStream {
  StreamController<SnackBar> streamController = StreamController();

  @override
  Stream<SnackBar> build() => streamController.stream;

  void add(SnackBar content) => streamController.add(content);
}

class SnackBarOverlay extends ConsumerWidget {
  const SnackBarOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue<SnackBar> value = ref.watch(snackbarStreamProvider);
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
    return child;
  }
}
