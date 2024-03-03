import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/Definitions/Action/BaseAction.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';
import 'package:tail_app/Backend/moveLists.dart';
import 'package:tail_app/Frontend/Widgets/speed_widget.dart';
import 'package:uuid/uuid.dart';

import '../../main.dart';
import '../Widgets/device_type_widget.dart';
import '../intnDefs.dart';

class MoveListView extends ConsumerStatefulWidget {
  const MoveListView({super.key});

  @override
  ConsumerState<MoveListView> createState() => _MoveListViewState();
}

class _MoveListViewState extends ConsumerState<MoveListView> {
  @override
  Widget build(BuildContext context) {
    final List<MoveList> allMoveLists = ref.watch(moveListsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            ref.watch(moveListsProvider.notifier).add(MoveList(sequencesPage(), DeviceType.values.toList(), ActionCategory.sequence, const Uuid().v4()));
            ref.watch(moveListsProvider.notifier).store();
          });
          plausible.event(name: "Add Sequence");
          context.push<MoveList>("/moveLists/editMoveList", extra: ref.watch(moveListsProvider).last).then((value) => setState(() {
                if (value != null) {
                  ref.watch(moveListsProvider).last = value;
                  ref.watch(moveListsProvider.notifier).store();
                }
              }));
        },
        label: Text(sequencesPage()),
      ),
      body: ListView.builder(
        itemCount: allMoveLists.length,
        primary: true,
        itemBuilder: (context, index) {
          return FadeIn(
              delay: Duration(milliseconds: index * 100),
              child: ListTile(
                title: Text(allMoveLists[index].name),
                subtitle: Text("${allMoveLists[index].moves.length} move(s)"), //TODO: Localize
                trailing: IconButton(
                  tooltip: sequencesEdit(),
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    context.push<MoveList>("/moveLists/editMoveList", extra: allMoveLists[index]).then(
                          (value) => setState(
                            () {
                              if (value != null) {
                                allMoveLists[index] = value;
                                ref.watch(moveListsProvider.notifier).store();
                              }
                            },
                          ),
                        );
                  },
                ),
                onTap: () async {
                  if (SentryHive.box('settings').get('haptics', defaultValue: true)) {
                    HapticFeedback.selectionClick();
                  }
                  ref.read(knownDevicesProvider).values.where((element) => allMoveLists[index].deviceCategory.contains(element.baseDeviceDefinition.deviceType)).forEach((element) {
                    runAction(allMoveLists[index], element);
                  });
                },
              ));
        },
      ),
    );
  }
}

class EditMoveList extends ConsumerStatefulWidget {
  const EditMoveList({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditMoveList();
}

class _EditMoveList extends ConsumerState<EditMoveList> with TickerProviderStateMixin {
  MoveList? moveList;
  TabController? _tabController;

  //TODO: Only store on back/save
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    setState(() {
      moveList ??= GoRouterState.of(context).extra! as MoveList; //Load stored data
      moveList ??= MoveList(sequencesAdd(), DeviceType.values.toList(), ActionCategory.sequence, const Uuid().v4()); // new if null, though it wont be stored
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(sequencesEdit()),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop(moveList)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: sequencesEditDeleteTitle(),
            onPressed: () {
              showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(sequencesEditDeleteTitle()),
                  content: Text(sequencesEditDeleteDescription()),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(cancel()),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(ok()),
                    ),
                  ],
                ),
              ).then((value) {
                if (value == true) {
                  ref.read(moveListsProvider.notifier).remove(moveList!);
                  ref.read(moveListsProvider.notifier).store();
                  context.pop();
                }
              });
            },
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        onPressed: () {
          setState(
            () {
              moveList!.moves.add(Move());
            },
          );
          editModal(context, moveList!.moves.length - 1);
          //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves.last).then((value) => setState(() => moveList!.moves.last = value!));
        },
        label: Text(sequencesEditAdd()),
      ),
      body: PopScope(
        onPopInvoked: (didPop) async {
          //This is broken >.<
          //https://github.com/flutter/flutter/issues/138737
          //https://github.com/flutter/flutter/issues/138525
          if (moveList!.moves.isEmpty) {
            ref.read(moveListsProvider.notifier).remove(moveList!);
          }
          ref.read(moveListsProvider.notifier).store();
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: TextEditingController(text: moveList!.name),
                decoration: InputDecoration(border: const OutlineInputBorder(), labelText: sequencesEditName()),
                maxLines: 1,
                maxLength: 30,
                autocorrect: false,
                onSubmitted: (nameValue) {
                  setState(
                    () {
                      moveList!.name = nameValue;
                    },
                  );
                  ref.read(moveListsProvider.notifier).store();
                },
              ),
            ),
            DeviceTypeWidget(
              selected: moveList!.deviceCategory,
              onSelectionChanged: (Set<DeviceType> value) {
                setState(() => moveList!.deviceCategory = value.toList());
                ref.read(moveListsProvider.notifier).store();
              },
            ),
            ListTile(
              title: Text(sequenceEditRepeatTitle()),
              leading: const Icon(Icons.repeat),
              subtitle: Slider(
                value: moveList!.repeat,
                min: 1,
                max: 5,
                divisions: 4,
                label: "${moveList!.repeat.toInt()}",
                onChanged: (double value) {
                  setState(() {
                    setState(() => moveList!.repeat = value);
                    ref.read(moveListsProvider.notifier).store();
                  });
                },
              ),
            ),
            Expanded(
              child: ReorderableListView(
                children: <Widget>[
                  for (int index = 0; index < moveList!.moves.length; index += 1)
                    FadeIn(
                        key: Key('$index'),
                        delay: Duration(milliseconds: (100 * index)),
                        child: ListTile(
                          title: Text(moveList!.moves[index].toString()),
                          leading: Icon(moveList!.moves[index].moveType.icon),
                          onTap: () {
                            editModal(context, index);
                            //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves[index]).then((value) => setState(() => moveList!.moves[index] = value!));
                          },
                        ))
                ],
                onReorder: (int oldIndex, int newIndex) {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  setState(
                    () {
                      final Move item = moveList!.moves.removeAt(oldIndex);
                      moveList!.moves.insert(newIndex, item);
                    },
                  );
                  ref.read(moveListsProvider.notifier).store();
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void editModal(BuildContext context, int index) {
    Move move = moveList!.moves[index];
    if (_tabController != null) {
      //There is probably a much better way to remove listeners
      _tabController?.dispose();
    }
    _tabController = TabController(length: 2, initialIndex: move.moveType.index, vsync: this);
    _tabController?.addListener(() {
      move.moveType = MoveType.values[_tabController!.index];
    });
    showModalBottomSheet<Move>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      clipBehavior: Clip.antiAliasWithSaveLayer,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setEditState) {
            return Scaffold(
              appBar: TabBar(
                controller: _tabController,
                tabs: <Widget>[
                  Tab(icon: const Icon(Icons.auto_graph), text: sequencesEditMove()),
                  Tab(
                    icon: const Icon(Icons.timer_rounded),
                    text: sequencesEditDelay(),
                  ),
                ],
              ),
              body: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  ListView(
                    children: [
                      ListTile(
                        title: Text(sequencesEditLeftServo()),
                        leading: const Icon(Icons.turn_slight_left),
                        subtitle: Slider(
                          value: move.leftServo,
                          max: 128,
                          divisions: 8,
                          label: "${move.leftServo.round().clamp(0, 128) ~/ 16}",
                          onChanged: (value) {
                            setEditState(() => move.leftServo = value);
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(sequencesEditRightServo()),
                        leading: const Icon(Icons.turn_slight_right),
                        subtitle: Slider(
                          value: move.rightServo,
                          max: 128,
                          divisions: 8,
                          label: "${move.rightServo.round().clamp(0, 128) ~/ 16}",
                          onChanged: (value) {
                            setEditState(() => move.rightServo = value);
                          },
                        ),
                      ),
                      SpeedWidget(
                        value: move.speed,
                        onChanged: (double value) {
                          setEditState(() => move.speed = value.roundToDouble());
                        },
                      ),
                      ListTile(
                        title: Text(sequencesEditEasing()),
                        subtitle: SegmentedButton<EasingType>(
                          selected: <EasingType>{move.easingType},
                          onSelectionChanged: (Set<EasingType> value) {
                            setEditState(() => move.easingType = value.first);
                          },
                          segments: EasingType.values.map<ButtonSegment<EasingType>>(
                            (EasingType value) {
                              return ButtonSegment<EasingType>(
                                value: value,
                                tooltip: value.name,
                                icon: value.widget(context),
                              );
                            },
                          ).toList(),
                        ),
                      )
                    ],
                  ),
                  ListView(
                    children: [
                      ListTile(
                        title: Text(sequencesEditTime()),
                        subtitle: Slider(
                          value: move.time,
                          label: "${move.time.toInt() * 20} ms",
                          max: 127,
                          min: 1,
                          divisions: 125,
                          onChanged: (value) {
                            setEditState(() => move.time = value.roundToDouble());
                          },
                        ),
                      )
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(
      () {
        setState(
          () {
            moveList!.moves[index] = move;
          },
        );
        ref.read(moveListsProvider.notifier).store();
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _tabController?.dispose();
  }
}
