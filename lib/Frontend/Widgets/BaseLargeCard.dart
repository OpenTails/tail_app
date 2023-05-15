import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';

class BaseLargeCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget page;

  const BaseLargeCard(this.title, this.children, this.page, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => page),
          );
        },
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
              textAlign: TextAlign.left,
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
    );
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
      child: InkWell(
        onTap: () async {
          Flogger.i("boop");
          //Set<BaseStatefulDevice> devices = ref.read(bluetoothProvider).knownDevices.value.where((element) => element.writeCharacteristic != null).where((element) => element.baseDeviceDefinition.deviceType == action.deviceCategory).toSet();
          //for (BaseStatefulDevice element in devices) {
          //  ref.read(bluetoothProvider).sendCommand(btMessage(action.command, element));
          //}
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
