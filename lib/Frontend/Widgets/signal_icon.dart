import 'package:flutter/material.dart';

class SignalIcon extends StatelessWidget {
  const SignalIcon({super.key, required this.rssi, required this.color});

  final int rssi;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (rssi == -1) {
      // Not Connected
      return Icon(
        Icons.signal_cellular_connected_no_internet_0_bar,
        color: color,
      );
    } else if (rssi < -80) {
      return Icon(Icons.signal_cellular_alt_1_bar, color: color);
    } else if (rssi < -60) {
      return Icon(Icons.signal_cellular_alt_2_bar, color: color);
    } else {
      return Icon(Icons.signal_cellular_alt, color: color);
    }
  }
}
