import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Backend/btMessage.dart';

import '../../main.dart';

class BaseLargeCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget page;

  const BaseLargeCard(this.title, this.children, this.page, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Card(
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
        child: Column(
          children: [
            Center(
              child: Text(
                title,
                textScaleFactor: 1.3,
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: children,
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class BaseHomeActionTile extends ConsumerWidget {
  const BaseHomeActionTile(
    this.action, {
    Key? key,
  }) : super(key: key);
  final BaseAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 1,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: InkWell(
        onTap: () async {
          Set<BaseStatefulDevice> devices = ref.read(bluetoothProvider).knownDevices.value.where((element) => element.writeCharacteristic != null).where((element) => element.baseDeviceDefinition.deviceType == action.deviceCategory).toSet();
          for (BaseStatefulDevice element in devices) {
            ref.read(bluetoothProvider).sendCommand(btMessage(action.command, element));
          }
        },
        child: SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: Text(action.name, textScaleFactor: 1.5),
            )),
      ),
    );
  }
}
