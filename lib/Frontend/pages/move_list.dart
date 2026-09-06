import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/Device/command/command_runner.dart';
import 'package:tail_app/Backend/move_lists_backend.dart';
import 'package:tail_app/Frontend/Widgets/group_card.dart';
import 'package:tail_app/Frontend/Widgets/section_label.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:uuid/uuid.dart';

import '../../Backend/Action/action_category.dart';
import '../../Backend/Action/base_action.dart';
import '../../Backend/Device/device_type_enum.dart';
import '../../Backend/analytics.dart';
import '../Widgets/device_type_widget.dart';
import '../Widgets/easing_types_widget.dart';
import '../Widgets/speed_widget.dart';
import '../Widgets/tutorial_card.dart';
import '../go_router_config.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';

class MoveListView extends StatefulWidget {
  const MoveListView({super.key});

  @override
  State<MoveListView> createState() => _MoveListViewState();
}

class _MoveListViewState extends State<MoveListView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(convertToUwU(sequencesPage()))),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Symbols.add),
        onPressed: () async {
          setState(() {
            MoveLists.instance.add(
              MoveList(
                name: sequencesAdd(),
                deviceCategory: DeviceType.values.toList(),
                actionCategory: ActionCategory.sequence,
                uuid: const Uuid().v4(),
              ),
            );
          });
          EditMoveListRoute($extra: MoveLists.instance.state.last)
              .push<MoveList>(context)
              .then(
                (value) => setState(() {
                  if (value != null) {
                    if (MoveLists.instance.state.isNotEmpty) {
                      MoveLists.instance.replace(
                        MoveLists.instance.state.last,
                        value,
                      );
                    } else {
                      MoveLists.instance.add(value);
                    }
                    MoveLists.instance.store();
                    analyticsEvent(
                      name: "Edit Custom Action",
                      props: {
                        "Number of Moves": value.moves.length.toString(),
                        "Repeat": value.repeat.toString(),
                      },
                    );
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
            PageInfoCard(text: sequencesInfoDescription()),
            const GearOutOfDateWarning(),
            ListenableBuilder(
              listenable: MoveLists.instance,
              builder: (context, child) {
                final BuiltList<MoveList> allMoveLists =
                    MoveLists.instance.state;

                return ListView.builder(
                  itemCount: allMoveLists.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return ListTile(
                      key: Key('$index'),
                      title: Text(convertToUwU(allMoveLists[index].name)),
                      subtitle: Text(
                        convertToUwU(
                          "${allMoveLists[index].moves.length} move(s)",
                        ),
                      ),
                      //TODO: Localize
                      trailing: IconButton(
                        tooltip: sequencesEdit(),
                        icon: const Icon(Symbols.edit),
                        onPressed: () async {
                          EditMoveListRoute($extra: allMoveLists[index])
                              .push<MoveList>(context)
                              .then(
                                (value) => setState(() {
                                  if (value != null) {
                                    MoveLists.instance.replace(
                                      allMoveLists[index],
                                      value,
                                    );
                                  }
                                }),
                              );
                        },
                      ),
                      onTap: () async {
                        runActionOnAllSupportedGear(
                          allMoveLists[index],
                          triggeredBy: "Custom Action Page",
                          useHaptics: true,
                        );
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

class EditMoveList extends StatefulWidget {
  const EditMoveList({required this.moveList, super.key});

  final MoveList moveList;

  @override
  State<StatefulWidget> createState() => _EditMoveList();
}

class _EditMoveList extends State<EditMoveList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(convertToUwU(sequencesEdit())),
        leading: IconButton(
          icon: const Icon(Symbols.arrow_back),
          onPressed: () => context.pop(widget.moveList),
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.delete),
            tooltip: sequencesEditDeleteTitle(),
            onPressed: () async {
              showDialog<bool>(
                context: context,
                barrierDismissible: false,
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
                  await MoveLists.instance.remove(widget.moveList);
                  analyticsEvent(
                    name: "Remove Custom Action",
                    props: {
                      "Number of Moves": widget.moveList.moves.length
                          .toString(),
                      "Repeat": widget.moveList.repeat.toString(),
                    },
                  );

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
              icon: const Icon(Symbols.add),
              onPressed: () async {
                setState(() {
                  widget.moveList.moves = widget.moveList.moves.toList()
                    ..add(Move());
                });
                Move move =
                    widget.moveList.moves[widget.moveList.moves.length - 1];

                EditMoveListMoveRoute($extra: move).push(context).whenComplete(
                  () {
                    setState(() {
                      widget.moveList.moves[widget.moveList.moves.length - 1] =
                          move;
                    });
                    MoveLists.instance.store();
                  },
                );
                //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves.last).then((value) => setState(() => moveList!.moves.last = value!));
              },
              label: Text(convertToUwU(sequencesEditAdd())),
            )
          : null,
      body: PopScope(
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            return;
          }
          //This is broken >.<
          //https://github.com/flutter/flutter/issues/138737
          //https://github.com/flutter/flutter/issues/138525
          if (widget.moveList.moves.isEmpty) {
            MoveLists.instance.remove(widget.moveList);
          }
          MoveLists.instance.store();
        },
        child: ListView(
          children: [
            PageInfoCard(text: sequencesInfoEditDescription()),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: TextEditingController(text: widget.moveList.name),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: sequencesEditName(),
                ),
                maxLines: 1,
                maxLength: 30,
                autocorrect: false,
                onSubmitted: (nameValue) async {
                  setState(() {
                    widget.moveList.name = nameValue;
                  });
                  MoveLists.instance.store();
                },
              ),
            ),
            DeviceTypeWidget(
              selected: widget.moveList.deviceCategory,
              onSelectionChanged: (List<DeviceType> value) async {
                setState(() => widget.moveList.deviceCategory = value.toList());
                MoveLists.instance.store();
              },
            ),
            ListTile(
              title: Text(convertToUwU(sequenceEditRepeatTitle())),
              leading: const Icon(Symbols.repeat),
              subtitle: Slider(
                value: widget.moveList.repeat,
                min: 1,
                max: 5,
                divisions: 4,
                label: "${widget.moveList.repeat.toInt()}",
                onChanged: (double value) async {
                  setState(() {
                    setState(() => widget.moveList.repeat = value);
                    MoveLists.instance.store();
                  });
                },
              ),
            ),
            ReorderableListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: widget.moveList.moves.length,
              itemBuilder: (context, index) {
                Move move = widget.moveList.moves[index];
                ProgressIndicatorThemeData progressIndicatorThemeData =
                    ProgressIndicatorTheme.of(context);
                ProgressIndicatorThemeData newProgressTheme =
                    progressIndicatorThemeData.copyWith(
                      linearMinHeight: 8,
                      borderRadius: BorderRadius.circular(radiusPill),
                    );
                return Card(
                  key: Key('$index'),
                  clipBehavior: Clip.antiAlias,
                  child: Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(progressIndicatorTheme: newProgressTheme),
                    child: ListTile(
                      subtitle: Padding(
                        padding: EdgeInsetsGeometry.symmetric(vertical: 16),
                        child: move.moveType == MoveType.move
                            ? Column(
                                spacing: 0,
                                children: [
                                  Row(
                                    spacing: 16,
                                    children: [
                                      SizedBox.square(
                                        dimension: IconTheme.of(context).size,
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: SectionLabel(
                                            convertToUwU(sequencesLeftServo()),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: SectionLabel(
                                            convertToUwU(sequencesRightServo()),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    spacing: 16,
                                    children: [
                                      Icon(Symbols.rotate_right),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: move.leftServo / 127,
                                        ),
                                      ),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: move.rightServo / 127,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    spacing: 16,
                                    children: [
                                      Icon(Symbols.speed),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: inverseDouble(
                                            0,
                                            1,
                                            move.leftServoSpeed / 127,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: inverseDouble(
                                            0,
                                            1,
                                            move.rightServoSpeed / 127,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Row(
                                spacing: 16,
                                children: [
                                  Icon(Symbols.timer_rounded),
                                  Expanded(
                                    child: LinearProgressIndicator(
                                      value: move.time / 127,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      trailing: IconButton(
                        onPressed: () {
                          setState(() {
                            widget.moveList.moves.removeAt(index);
                          });
                        },
                        icon: Icon(Symbols.delete),
                      ),
                      onTap: () async {
                        EditMoveListMoveRoute(
                          $extra: move,
                        ).push(context).whenComplete(() {
                          setState(() {
                            widget.moveList.moves[index] = move;
                          });
                          MoveLists.instance.store();
                        });
                        //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves[index]).then((value) => setState(() => moveList!.moves[index] = value!));
                      },
                    ),
                  ),
                );
              },
              onReorderItem: (int oldIndex, int newIndex) async {
                setState(() {
                  final Move item = widget.moveList.moves.removeAt(oldIndex);
                  widget.moveList.moves.insert(newIndex, item);
                });
                MoveLists.instance.store();
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

class EditMove extends StatefulWidget {
  const EditMove({required this.move, super.key});

  @override
  State<StatefulWidget> createState() => _EditMoveState();
  final Move move;
}

class _EditMoveState extends State<EditMove> with TickerProviderStateMixin {
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.move.moveType.index,
      vsync: this,
    );
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
                Tab(
                  icon: const Icon(Symbols.auto_graph),
                  text: sequencesEditMove(),
                ),
                Tab(
                  icon: const Icon(Symbols.timer_rounded),
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
                    padding: sectionedListViewPadding,

                    controller: scrollController,
                    children: [
                      SectionLabel(convertToUwU(sequencesLeftServo())),
                      GroupCard(
                        children: [
                          ListTile(
                            title: Text(convertToUwU(sequencesEditLeftServo())),
                            leading: const Icon(Icons.turn_slight_left),
                            subtitle: Slider(
                              value: widget.move.leftServo,
                              max: 128,
                              divisions: 8,
                              label:
                                  "${widget.move.leftServo.round().clamp(0, 128) ~/ 16}",
                              onChanged: (value) {
                                setState(() => widget.move.leftServo = value);
                              },
                            ),
                          ),
                          SpeedWidget(
                            value: widget.move.leftServoSpeed,
                            onChanged: (double value) {
                              setState(
                                () => widget.move.leftServoSpeed = value
                                    .roundToDouble(),
                              );
                            },
                          ),
                          EasingTypesWidget(
                            value: widget.move.leftServoEasingType,
                            onSelectionChanged: (Set<EasingType> value) {
                              setState(
                                () => widget.move.leftServoEasingType =
                                    value.first,
                              );
                            },
                          ),
                        ],
                      ),
                      SectionLabel(convertToUwU(sequencesRightServo())),
                      GroupCard(
                        children: [
                          ListTile(
                            title: Text(
                              convertToUwU(sequencesEditRightServo()),
                            ),
                            leading: const Icon(Icons.turn_slight_right),
                            subtitle: Slider(
                              value: widget.move.rightServo,
                              max: 128,
                              divisions: 8,
                              label:
                                  "${widget.move.rightServo.round().clamp(0, 128) ~/ 16}",
                              onChanged: (value) {
                                setState(() => widget.move.rightServo = value);
                              },
                            ),
                          ),
                          SpeedWidget(
                            value: widget.move.rightServoSpeed,
                            onChanged: (double value) {
                              setState(
                                () => widget.move.rightServoSpeed = value
                                    .roundToDouble(),
                              );
                            },
                          ),
                          EasingTypesWidget(
                            value: widget.move.rightServoEasingType,
                            onSelectionChanged: (Set<EasingType> value) {
                              setState(
                                () => widget.move.rightServoEasingType =
                                    value.first,
                              );
                            },
                          ),
                        ],
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
                            setState(
                              () => widget.move.time = value.roundToDouble(),
                            );
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
