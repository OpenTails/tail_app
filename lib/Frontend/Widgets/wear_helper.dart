import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/wear_bridge.dart';

class WearHelper extends ConsumerWidget {
  const WearHelper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the theme data from context
    ThemeData theme = Theme.of(context);
    WearThemeData themeData = WearThemeData(primary: theme.colorScheme.primary.toARGB32(), secondary: theme.colorScheme.secondary.toARGB32());
    wearThemeData = themeData;
    // ignore: unused_result
    updateWearData();
    return child;
  }
}
