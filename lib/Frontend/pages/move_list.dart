import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/pages/direct_gear_control.dart';
import 'package:uuid/uuid.dart';

import '../../Backend/Bluetooth/bluetooth_manager.dart';
import '../../Backend/Definitions/Action/base_action.dart';
import '../../Backend/Definitions/Device/device_definition.dart';
import '../../Backend/logging_wrappers.dart';
import '../../Backend/move_lists.dart';
import '../../Backend/plausible_dio.dart';
import '../../constants.dart';
import '../Widgets/device_type_widget.dart';
import '../Widgets/speed_widget.dart';
import '../Widgets/tutorial_card.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';

class MoveListView extends ConsumerStatefulWidget {
  const MoveListView({super.key});

  @override
  ConsumerState<MoveListView> createState() => _MoveListViewState();
}

class _MoveListViewState extends ConsumerState<MoveListView> {
  @override
  Widget build(BuildContext context) {
    final BuiltList<MoveList> allMoveLists = ref.watch(moveListsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(convertToUwU(sequencesPage()))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        onPressed: () async {
          setState(() {
            ref.watch(moveListsProvider.notifier).add(MoveList(name: sequencesPage(), deviceCategory: DeviceType.values.toList(), actionCategory: ActionCategory.sequence, uuid: const Uuid().v4()));
          });
          plausible.event(name: "Add Sequence");
          EditMoveListRoute($extra: ref.watch(moveListsProvider).last).push<MoveList>(context).then(
                (value) => setState(() {
                  if (value != null) {
                    if (ref.watch(moveListsProvider).isNotEmpty) {
                      ref.watch(moveListsProvider.notifier).replace(ref.read(moveListsProvider).last, value);
                    } else {
                      ref.watch(moveListsProvider.notifier).add(value);
                    }
                    ref.watch(moveListsProvider.notifier).store();
                  }
                }),
              );
        },
        label: Text(convertToUwU(sequencesPage())),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            PageInfoCard(
              text: sequencesInfoDescription(),
            ),
            const GearOutOfDateWarning(),
            ListView.builder(
              itemCount: allMoveLists.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return ListTile(
                  key: Key('$index'),
                  title: Text(convertToUwU(allMoveLists[index].name)),
                  subtitle: Text(convertToUwU("${allMoveLists[index].moves.length} move(s)")),
                  //TODO: Localize
                  trailing: IconButton(
                    tooltip: sequencesEdit(),
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      EditMoveListRoute($extra: allMoveLists[index]).push<MoveList>(context).then(
                            (value) => setState(
                              () {
                                if (value != null) {
                                  ref.watch(moveListsProvider.notifier).replace(allMoveLists[index], value);
                                }
                              },
                            ),
                          );
                    },
                  ),
                  onTap: () async {
                    if (HiveProxy.getOrDefault(settings, haptics, defaultValue: hapticsDefault)) {
                      HapticFeedback.selectionClick();
                    }
                    ref
                        .watch(knownDevicesProvider)
                        .values
                        .where(
                          (element) => allMoveLists[index].deviceCategory.contains(element.baseDeviceDefinition.deviceType),
                        )
                        .where(
                          (element) => element.deviceState.value == DeviceState.standby,
                        )
                        .forEach(
                      (element) async {
                        if (HiveProxy.getOrDefault(settings, kitsuneModeToggle, defaultValue: kitsuneModeDefault)) {
                          await Future.delayed(Duration(milliseconds: Random().nextInt(kitsuneDelayRange)));
                        }
                        ref.read(runActionProvider(element).notifier).runAction(allMoveLists[index]);
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class EditMoveList extends ConsumerStatefulWidget {
  const EditMoveList({required this.moveList, super.key});

  final MoveList moveList;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditMoveList();
}

class _EditMoveList extends ConsumerState<EditMoveList> {
  //TODO: Only store on back/save
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(convertToUwU(sequencesEdit())),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop(widget.moveList)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: sequencesEditDeleteTitle(),
            onPressed: () async {
              showDialog<bool>(
                context: context,
                builder: (BuildContext context) => AlertDialog(
                  title: Text(convertToUwU(sequencesEditDeleteTitle())),
                  content: Text(convertToUwU(sequencesEditDeleteDescription())),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(convertToUwU(cancel())),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(convertToUwU(ok())),
                    ),
                  ],
                ),
              ).then((value) async {
                if (value ?? true) {
                  await ref.watch(moveListsProvider.notifier).remove(widget.moveList);
                  await ref.watch(moveListsProvider.notifier).store();
                  if (context.mounted) {
                    context.pop();
                  }
                }
              });
            },
          ),
        ],
      ),
      floatingActionButton: widget.moveList.moves.length < 6
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              onPressed: () async {
                setState(
                  () {
                    widget.moveList.moves = widget.moveList.moves.toList()..add(Move());
                  },
                );
                Move move = widget.moveList.moves[widget.moveList.moves.length - 1];

                EditMoveListMoveRoute($extra: move).push(context).whenComplete(
                  () {
                    setState(
                      () {
                        widget.moveList.moves[widget.moveList.moves.length - 1] = move;
                      },
                    );
                    ref.watch(moveListsProvider.notifier).store();
                  },
                );
                //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves.last).then((value) => setState(() => moveList!.moves.last = value!));
              },
              label: Text(convertToUwU(sequencesEditAdd())),
            )
          : null,
      body: PopScope(
        onPopInvoked: (didPop) async {
          //This is broken >.<
          //https://github.com/flutter/flutter/issues/138737
          //https://github.com/flutter/flutter/issues/138525
          if (widget.moveList.moves.isEmpty) {
            ref.watch(moveListsProvider.notifier).remove(widget.moveList);
          }
          ref.watch(moveListsProvider.notifier).store();
        },
        child: ListView(
          children: [
            PageInfoCard(
              text: sequencesInfoEditDescription(),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: TextEditingController(text: widget.moveList.name),
                decoration: InputDecoration(border: const OutlineInputBorder(), labelText: sequencesEditName()),
                maxLines: 1,
                maxLength: 30,
                autocorrect: false,
                onSubmitted: (nameValue) async {
                  setState(
                    () {
                      widget.moveList.name = nameValue;
                    },
                  );
                  ref.watch(moveListsProvider.notifier).store();
                },
              ),
            ),
            DeviceTypeWidget(
              selected: widget.moveList.deviceCategory,
              onSelectionChanged: (List<DeviceType> value) async {
                setState(() => widget.moveList.deviceCategory = value.toList());
                ref.watch(moveListsProvider.notifier).store();
              },
            ),
            ListTile(
              title: Text(convertToUwU(sequenceEditRepeatTitle())),
              leading: const Icon(Icons.repeat),
              subtitle: Slider(
                value: widget.moveList.repeat,
                min: 1,
                max: 5,
                divisions: 4,
                label: "${widget.moveList.repeat.toInt()}",
                onChanged: (double value) async {
                  setState(() {
                    setState(() => widget.moveList.repeat = value);
                    ref.watch(moveListsProvider.notifier).store();
                  });
                },
              ),
            ),
            ReorderableListView(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              children: <Widget>[
                for (int index = 0; index < widget.moveList.moves.length; index += 1)
                  ListTile(
                    key: Key('$index'),
                    title: Text(convertToUwU(widget.moveList.moves[index].toString())),
                    leading: Icon(widget.moveList.moves[index].moveType.icon),
                    onTap: () async {
                      Move move = widget.moveList.moves[index];

                      EditMoveListMoveRoute($extra: move).push(context).whenComplete(
                        () {
                          setState(
                            () {
                              widget.moveList.moves[index] = move;
                            },
                          );
                          ref.watch(moveListsProvider.notifier).store();
                        },
                      );
                      //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves[index]).then((value) => setState(() => moveList!.moves[index] = value!));
                    },
                  ),
              ],
              onReorder: (int oldIndex, int newIndex) async {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                setState(
                  () {
                    final Move item = widget.moveList.moves.removeAt(oldIndex);
                    widget.moveList.moves.insert(newIndex, item);
                  },
                );
                ref.watch(moveListsProvider.notifier).store();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class EditMove extends ConsumerStatefulWidget {
  const EditMove({required this.move, super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditMoveState();
  final Move move;
}

class _EditMoveState extends ConsumerState<EditMove> with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, initialIndex: widget.move.moveType.index, vsync: this);
    _tabController?.addListener(() {
      widget.move.moveType = MoveType.values[_tabController!.index];
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (BuildContext context, ScrollController scrollController) {
        return Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: <Widget>[
                Tab(icon: const Icon(Icons.auto_graph), text: sequencesEditMove()),
                Tab(
                  icon: const Icon(Icons.timer_rounded),
                  text: sequencesEditDelay(),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: <Widget>[
                  ListView(
                    shrinkWrap: true,
                    controller: scrollController,
                    children: [
                      /* Joystick(
                        disableRecenterOnDragEnd: true,
                        includeInitialAnimation: false,
                        initialOffset: calculateInitialJoystickPosition(
                          TailServoPositions(left: widget.move.leftServo, right: widget.move.rightServo),
                        ),
                        base: const Card(
                          elevation: 3,
                          shape: CircleBorder(),
                          child: SizedBox.square(dimension: 300),
                        ),
                        stick: Card(
                          elevation: 2,
                          shape: const CircleBorder(),
                          color: Theme.of(context).colorScheme.primary,
                          child: const SizedBox.square(dimension: 100),
                        ),
                        listener: (details) {
                          TailServoPositions positions = calculatePosition(details);
                          setState(() {
                            widget.move.leftServo = positions.left;
                            widget.move.rightServo = positions.right;
                          });
                        },
                      ), */
                      ListTile(
                        title: Text(convertToUwU(sequencesEditLeftServo())),
                        leading: const Icon(Icons.turn_slight_left),
                        subtitle: Slider(
                          value: widget.move.leftServo,
                          max: 128,
                          divisions: 8,
                          label: "${widget.move.leftServo.round().clamp(0, 128) ~/ 16}",
                          onChanged: (value) {
                            setState(() => widget.move.leftServo = value);
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(convertToUwU(sequencesEditRightServo())),
                        leading: const Icon(Icons.turn_slight_right),
                        subtitle: Slider(
                          value: widget.move.rightServo,
                          max: 128,
                          divisions: 8,
                          label: "${widget.move.rightServo.round().clamp(0, 128) ~/ 16}",
                          onChanged: (value) {
                            setState(() => widget.move.rightServo = value);
                          },
                        ),
                      ),
                      SpeedWidget(
                        value: widget.move.speed,
                        onChanged: (double value) {
                          setState(() => widget.move.speed = value.roundToDouble());
                        },
                      ),
                      ListTile(
                        title: Text(convertToUwU(sequencesEditEasing())),
                        subtitle: SegmentedButton<EasingType>(
                          selected: <EasingType>{widget.move.easingType},
                          onSelectionChanged: (Set<EasingType> value) {
                            setState(() => widget.move.easingType = value.first);
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
                      ),
                    ],
                  ),
                  ListView(
                    shrinkWrap: true,
                    controller: scrollController,
                    children: [
                      ListTile(
                        title: Text(convertToUwU(sequencesEditTime())),
                        subtitle: Slider(
                          value: widget.move.time,
                          label: "${widget.move.time.toInt() * 20} ms",
                          max: 127,
                          min: 1,
                          divisions: 125,
                          onChanged: (value) {
                            setState(() => widget.move.time = value.roundToDouble());
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    super.dispose();
    _tabController?.dispose();
  }
}
