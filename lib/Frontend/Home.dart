import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:tail_app/Backend/ActionRegistry.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

import '../main.dart';
import 'Actions.dart';
import 'Widgets/BaseLargeCard.dart';

class Home extends ConsumerStatefulWidget {
  const Home({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  ConsumerState<Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<Home> {
  void changed(List<dynamic> changed) {}

  @override
  Widget build(BuildContext context) {
    Flogger.d('Building Home');
    return Scaffold(
      body: NestedScrollView(
        body: Center(
          child: ListView(
            children: <Widget>[
              devicesChipsWidget(ref),
              const BaseLargeCard("Favorites", [], ActionPage()),
              BaseLargeCard("Actions", getActionTiles(), const ActionPage()),
              const BaseLargeCard("Triggers", [], ActionPage()),
              const BaseLargeCard("Move Lists", [], ActionPage()),
              const BaseLargeCard("Alarms", [], ActionPage()),
              const BaseLargeCard("Casual Mode", [], ActionPage()),
            ],
          ),
        ),
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              title: Text(
                widget.title,
              ),
              floating: true,
              expandedHeight: 200.0,
              forceElevated: innerBoxIsScrolled,
              pinned: true,
            ),
          ];
        },
      ),
      drawer: drawer(context),
    );
  }

  Widget devicesChipsWidget(WidgetRef ref) {
    return ValueListenableBuilder(
        builder: (context, value, child) {
          return ChipsChoice.multiple(
              wrapped: true,
              choiceItems: () {
                List<C2Choice> items = [];
                for (BaseStatefulDevice device in ref.read(bluetoothProvider).knownDevices.value) {
                  items.add(C2Choice(value: device, label: device.baseStoredDevice.name));
                }
                items.add(C2Choice(value: value, label: "Scan"));
                return items;
              }(),
              onChanged: (val) {
                changed(val);
                //Prompt to disconnect/remove on long press
              },
              value: const []);
        },
        valueListenable: ref.watch(bluetoothProvider).knownDevices);
  }

  List<BaseHomeActionTile> getActionTiles() {
    List<BaseHomeActionTile> tiles = [];
    for (BaseAction baseAction in ActionRegistry.allCommands) {
      tiles.add(BaseHomeActionTile(baseAction));
    }
    return tiles;
  }

  Widget drawer(BuildContext context) {
    return Drawer(
        child: Column(children: <Widget>[
      const DrawerHeader(
        child: Text(
          'All of the Tails',
        ),
      ),
      ListTile(
        title: const Text('About'),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const AboutDialog(
                      applicationName: "Tail_App",
                      applicationVersion: "0.0.1",
                      applicationLegalese: "This is a fan made app to control 'The Tail Company' tails and ears",
                    )),
          );
        },
      ),
      ListTile(
        title: const Text('Logs'),
        onTap: () {
          LogConsole.open(context);
        },
      ),
      ListTile(
        title: const Text('Scan'),
        onTap: () {
          ref.read(bluetoothProvider).scan();
        },
      ),
    ]));
  }
}
