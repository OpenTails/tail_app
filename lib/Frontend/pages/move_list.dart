import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:tail_app/Backend/Bluetooth/BluetoothManager.dart';
import 'package:tail_app/Backend/moveLists.dart';

import '../../Backend/Settings.dart';

class MoveListView extends ConsumerStatefulWidget {
  const MoveListView({super.key});

  @override
  ConsumerState<MoveListView> createState() => _MoveListViewState();
}

class _MoveListViewState extends ConsumerState<MoveListView> {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    final List<MoveList> allMoveLists = ref.watch(moveListsProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        onPressed: () {
          setState(() {
            ref.watch(moveListsProvider.notifier).add(MoveList());
            ref.watch(moveListsProvider.notifier).store();
          });
          context.push<MoveList>("/moveLists/editMoveList", extra: ref.watch(moveListsProvider).last).then((value) => setState(() {
                if (value != null) {
                  ref.watch(moveListsProvider).last = value;
                  ref.watch(moveListsProvider.notifier).store();
                }
              }));
        },
        label: const Text("New Move Sequences"),
      ),
      body: ListView.builder(
        itemCount: allMoveLists.length,
        controller: _controller,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(allMoveLists[index].name),
            subtitle: Text("${allMoveLists[index].moves.length} moves"),
            trailing: IconButton(
              tooltip: "Edit Sequence",
              icon: const Icon(Icons.edit),
              onPressed: () {
                context.push<MoveList>("/moveLists/editMoveList", extra: allMoveLists[index]).then((value) => setState(() {
                      if (value != null) {
                        allMoveLists[index] = value;
                        ref.watch(moveListsProvider.notifier).store();
                      }
                    }));
              },
            ),
            onTap: () async {
              if (ref.read(preferencesProvider).haptics) {
                await Haptics.vibrate(HapticsType.selection);
              }
              ref.read(knownDevicesProvider).values.forEach((element) {
                runMove(allMoveLists[index], element);
              });
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}

class EditMoveList extends ConsumerStatefulWidget {
  const EditMoveList({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _EditMoveList();
}

class _EditMoveList extends ConsumerState<EditMoveList> with TickerProviderStateMixin {
  final ScrollController _controller = ScrollController();
  MoveList? moveList;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    setState(() {
      moveList ??= GoRouterState.of(context).extra! as MoveList; //Load stored data
      moveList ??= MoveList(); // new if null
    });
    return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Move Sequence'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop(moveList)),
        ),
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          onPressed: () {
            setState(() {
              moveList!.moves.add(Move());
            });
            editModal(context, moveList!.moves.length - 1);
            ref.watch(moveListsProvider.notifier).store();
            //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves.last).then((value) => setState(() => moveList!.moves.last = value!));
          },
          label: const Text("Add Move"),
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
                controller: TextEditingController(text: moveList!.name),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Name'),
                maxLines: 1,
                maxLength: 30,
                autocorrect: false,
                onSubmitted: (nameValue) {
                  setState(() {
                    moveList!.name = nameValue;
                  });
                  ref.watch(moveListsProvider.notifier).store();
                }),
          ),
          Expanded(
            child: ReorderableListView(
              children: <Widget>[
                for (int index = 0; index < moveList!.moves.length; index += 1)
                  ListTile(
                    key: Key('$index'),
                    title: Text(moveList!.moves[index].toString()),
                    leading: Icon(moveList!.moves[index].moveType.icon),
                    onTap: () {
                      editModal(context, index);
                      //context.push<Move>("/moveLists/editMoveList/editMove", extra: moveList!.moves[index]).then((value) => setState(() => moveList!.moves[index] = value!));
                    },
                  )
              ],
              onReorder: (int oldIndex, int newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final Move item = moveList!.moves.removeAt(oldIndex);
                moveList!.moves.insert(newIndex, item);
              },
            ),
          )
        ]));
  }

  void editModal(BuildContext context, int index) {
    Move move = moveList!.moves[index];
    if (_tabController != null) {
      //There is probably a much better way to remove listeners
      _tabController?.dispose();
    }
    _tabController = TabController(length: 3, initialIndex: move.moveType.index, vsync: this);
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
          return StatefulBuilder(builder: (BuildContext context, StateSetter setEditState) {
            return Scaffold(
              appBar: TabBar(controller: _tabController, tabs: const <Widget>[
                Tab(icon: Icon(Icons.auto_graph), text: "Move"),
                Tab(
                  icon: Icon(Icons.timer_rounded),
                  text: "Delay",
                ),
                Tab(
                  icon: Icon(Icons.home),
                  text: "Home",
                ),
              ]),
              body: TabBarView(controller: _tabController, children: <Widget>[
                ListView(
                  children: [
                    ListTile(
                      title: const Text("Left Servo"),
                      subtitle: Slider(
                        value: move.leftServo,
                        max: 128,
                        divisions: 8,
                        onChanged: (value) {
                          setEditState(() => move.leftServo = value);
                          ref.watch(moveListsProvider.notifier).store();
                        },
                      ),
                    ),
                    ListTile(
                      title: const Text("Right Servo"),
                      subtitle: Slider(
                        value: move.rightServo,
                        max: 128,
                        divisions: 8,
                        onChanged: (value) {
                          setEditState(() => move.rightServo = value);
                          ref.watch(moveListsProvider.notifier).store();
                        },
                      ),
                    ),
                    ListTile(
                        title: const Text("Speed"),
                        subtitle: SegmentedButton<Speed>(
                          selected: <Speed>{move.speed},
                          onSelectionChanged: (Set<Speed> value) {
                            setEditState(() => move.speed = value.first);
                            ref.watch(moveListsProvider.notifier).store();
                          },
                          segments: Speed.values.map<ButtonSegment<Speed>>((Speed value) {
                            return ButtonSegment<Speed>(
                              value: value,
                              label: Text(value.name),
                            );
                          }).toList(),
                        )),
                    ListTile(
                        title: const Text("Easing Type"),
                        subtitle: SegmentedButton<EasingType>(
                          selected: <EasingType>{move.easingType},
                          onSelectionChanged: (Set<EasingType> value) {
                            setEditState(() => move.easingType = value.first);
                            ref.watch(moveListsProvider.notifier).store();
                          },
                          segments: EasingType.values.map<ButtonSegment<EasingType>>((EasingType value) {
                            return ButtonSegment<EasingType>(
                              value: value,
                              label: Text(value.name),
                            );
                          }).toList(),
                        ))
                  ],
                ),
                ListView(
                  controller: _controller,
                  children: [
                    ListTile(
                      title: const Text("Time"),
                      subtitle: Slider(
                        value: move.time,
                        max: 10,
                        min: 1,
                        divisions: 9,
                        onChanged: (value) {
                          setEditState(() => move.time = value);
                          ref.watch(moveListsProvider.notifier).store();
                        },
                      ),
                    )
                  ],
                ),
                const Center(
                  child: Text("It's sunny here"),
                ),
              ]),
            );
          });
        }).whenComplete(() => setState(() {
          moveList!.moves[index] = move;
          ref.watch(moveListsProvider.notifier).store();
        }));
  }

  @override
  void dispose() {
    super.dispose();
    _tabController?.dispose();
    _controller.dispose();
  }
}
