import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/Device/stateful/connected_gear.dart';
import 'package:tail_app/Frontend/theme_helpers.dart';
import 'package:tail_app/constants.dart';

class GearBatteryBar extends StatelessWidget {
  const GearBatteryBar({
    super.key,
    required this.statefulDevice,
    required this.textColor,
    this.showPercentage = false,
  });

  final StatefulDevice statefulDevice;
  final Color textColor;
  final bool showPercentage;
  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: ListenableBuilder(
        listenable: statefulDevice.battery,
        builder: (context, child) => Stack(
          alignment: AlignmentGeometry.center,
          children: [
            Flash(
              animate: statefulDevice.battery.isLow,
              infinite: true,
              child: LinearProgressIndicator(
                minHeight: 16,
                color: textColor,
                backgroundColor: textColor.withAlpha(100),
                borderRadius: BorderRadius.circular(16),
                value: statefulDevice.battery.averagedCurrentLevel > -1
                    ? statefulDevice.battery.averagedCurrentLevel / 100
                    : null,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Icon(
                  statefulDevice.battery.isCharging
                      ? Symbols.battery_android_bolt_rounded
                      : Symbols.battery_android_0,
                  color: getTextColor(
                    color: textColor,
                    context: context,
                    invert: false,
                  ),
                ),
                if (showPercentage) ...[
                  Text(
                    "${statefulDevice.battery.averagedCurrentLevel.toInt()}%",
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      secondChild: Icon(Symbols.bluetooth_disabled, color: textColor),
      crossFadeState: statefulDevice.isReady
          ? CrossFadeState.showFirst
          : CrossFadeState.showSecond,
      duration: animationTransitionDuration,
    );
  }
}