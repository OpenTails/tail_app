import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Frontend/Widgets/speed_widget.dart';
import 'package:vector_math/vector_math.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Bluetooth/bluetooth_message.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/move_lists.dart';
import '../../constants.dart';
import '../Widgets/device_type_widget.dart';
import '../translation_string_definitions.dart';

class DirectGearControl extends ConsumerStatefulWidget {
  const DirectGearControl({super.key});

  @override
  ConsumerState<DirectGearControl> createState() => _JoystickState();
}

class _JoystickState extends ConsumerState<DirectGearControl> {
  double left = 0;
  double right = 0;
  double x = 0;
  double y = 0;
  double direction = 0;
  double magnitude = 0;
  double speed = 25;
  EasingType easingType = EasingType.linear;
  Set<DeviceType> deviceTypes = DeviceType.values.toSet();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Joystick(
                      mode: JoystickMode.all,
                      onStickDragEnd: () async {
                        await Future.delayed(Duration(milliseconds: (speed * 20).toInt()));
                        Move move = Move();
                        move.moveType = MoveType.home;
                        ref.read(knownDevicesProvider).values.forEach(
                          (element) {
                            generateMoveCommand(move, element, Type.direct).forEach(
                              (message) {
                                message.responseMSG = null;
                                message.priority = Priority.high;
                                element.commandQueue.addCommand(message);
                              },
                            );
                          },
                        );
                      },
                      base: const Card(
                        elevation: 1,
                        shape: CircleBorder(),
                        child: SizedBox.square(dimension: 300),
                      ),
                      stick: Card(
                        elevation: 2,
                        shape: const CircleBorder(),
                        color: Theme.of(context).primaryColor,
                        child: const SizedBox.square(dimension: 100),
                      ),
                      listener: (details) {
                        setState(
                          () {
                            if (SentryHive.box(settings).get(haptics, defaultValue: hapticsDefault)) {
                              HapticFeedback.selectionClick();
                            }
                            x = details.x;
                            y = details.y;

                            double sign = x.sign;
                            direction = degrees(atan2(y.abs(), x.abs())); // 0-90
                            magnitude = sqrt(pow(x.abs(), 2).toDouble() + pow(y.abs(), 2).toDouble());

                            double secondServo = ((((direction - 0) * (128 - 0)) / (90 - 0)) + 0).clamp(0, 128);
                            double primaryServo = ((((magnitude - 0) * (128 - 0)) / (1 - 0)) + 0).clamp(0, 128);
                            if (sign > 0) {
                              left = primaryServo;
                              right = secondServo;
                            } else {
                              right = primaryServo;
                              left = secondServo;
                            }
                          },
                        );
                        sendMove();
                      },
                      period: Duration(milliseconds: (speed * 20).toInt()),
                    ),
                  ),
                ],
              ),
              if (SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault)) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 400, 8, 8),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Magnitude: ${magnitude.toStringAsPrecision(2)}"),
                        Text("Direction: ${direction.toInt()}"),
                        Text("Left: ${left.toInt()}"),
                        Text("Right: ${right.toInt()}"),
                        Text("X: ${x.toStringAsPrecision(2)}"),
                        Text("Y: ${y.toStringAsPrecision(2)}"),
                      ],
                    ),
                  ),
                )
              ],
              ExpansionTile(
                title: Text(settingsPage()),
                initiallyExpanded: MediaQuery.sizeOf(context).height > 900,
                backgroundColor: Theme.of(context).cardColor,
                children: [
                  SpeedWidget(
                    value: speed,
                    onChanged: (double value) {
                      setState(
                        () {
                          speed = value;
                        },
                      );
                    },
                  ),
                  ListTile(
                    title: Text(sequencesEditEasing()),
                    subtitle: SegmentedButton<EasingType>(
                      selected: <EasingType>{easingType},
                      onSelectionChanged: (Set<EasingType> value) {
                        setState(
                          () {
                            easingType = value.first;
                          },
                        );
                      },
                      segments: EasingType.values.map<ButtonSegment<EasingType>>(
                        (EasingType value) {
                          return ButtonSegment<EasingType>(value: value, icon: value.widget(context), tooltip: value.name);
                        },
                      ).toList(),
                    ),
                  ),
                  DeviceTypeWidget(
                    selected: deviceTypes.toList(),
                    onSelectionChanged: (List<DeviceType> value) {
                      setState(() => deviceTypes = value.toSet());
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  void sendMove() {
    Move move = Move();
    move.easingType = easingType;
    move.speed = speed;
    move.rightServo = right;
    move.leftServo = left;
    ref.read(knownDevicesProvider).values.where((element) => deviceTypes.contains(element.baseDeviceDefinition.deviceType)).forEach(
      (element) {
        generateMoveCommand(move, element, Type.direct).forEach(
          (message) {
            message.responseMSG = null;
            message.priority = Priority.high;
            element.commandQueue.addCommand(message);
          },
        );
      },
    );
  }
}
