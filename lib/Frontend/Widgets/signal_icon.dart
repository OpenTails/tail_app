import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SignalIcon extends StatelessWidget {
  const SignalIcon({super.key, required this.rssi, this.color});

  final int rssi;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    Color iconColor = color ?? Theme.of(context).colorScheme.onSurface;
    if (rssi == -1) {
      // Not Connected
      return Icon(
        Symbols.signal_cellular_connected_no_internet_0_bar,
        color: iconColor,
      );
    } else if (rssi < -80) {
      return Icon(Symbols.signal_cellular_alt_1_bar, color: iconColor);
    } else if (rssi < -60) {
      return Icon(Symbols.signal_cellular_alt_2_bar, color: iconColor);
    } else {
      return Icon(Symbols.signal_cellular_alt, color: iconColor);
    }
  }
}
