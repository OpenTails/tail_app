import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/audio.dart';
import 'package:uuid/uuid.dart';

import '../Widgets/tutorial_card.dart';
import '../translation_string_definitions.dart';

final Logger _audioLogger = Logger('Audio');

class CustomAudio extends ConsumerStatefulWidget {
  const CustomAudio({super.key});

  @override
  ConsumerState<CustomAudio> createState() => _CustomAudioState();
}

class _CustomAudioState extends ConsumerState<CustomAudio> {
  @override
  Widget build(BuildContext context) {
    List<AudioAction> userAudioActions = ref.watch(userAudioActionsProvider);
    return Scaffold(
        appBar: AppBar(
          title: Text(audioPage()),
        ),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              _audioLogger.info("Opening file dialog");
              FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio, withReadStream: true);
              if (result != null) {
                _audioLogger.info("Selected file");
                PlatformFile file = result.files.first;
                final Directory appDir = await getApplicationSupportDirectory();
                Directory audioDir = Directory("${appDir.path}/audio");
                await audioDir.create();
                File storedAudioFilePath = File("${audioDir.path}/${file.name}");
                _audioLogger.info("File path ${storedAudioFilePath.path}");
                _audioLogger.info("Selected file Path ${file.path}");
                Stream<List<int>> openRead = file.readStream!;
                IOSink ioSinkWrite = storedAudioFilePath.openWrite();
                await ioSinkWrite.addStream(openRead);
                ioSinkWrite.close();
                _audioLogger.info("Wrote file to app storage");
                AudioAction action = AudioAction(
                  name: file.name.substring(0, file.name.lastIndexOf(".")).replaceAll("_", " ").replaceAll("-", " "),
                  uuid: const Uuid().v4(),
                  file: storedAudioFilePath.path,
                );
                setState(() {
                  ref.read(userAudioActionsProvider.notifier).add(action);
                });
              }
              //Open File Picker
            },
            icon: const Icon(Icons.add),
            label: Text(audioAdd())),
        body: ListView(
          children: [
            PageInfoCard(
              text: audioTipCard(),
            ),
            ListView.builder(
              itemCount: userAudioActions.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                AudioAction audioAction = userAudioActions[index];
                return ListTile(
                  title: Text(audioAction.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          editModal(context, audioAction);
                        },
                        tooltip: audioEdit(),
                        icon: const Icon(Icons.edit),
                      ),
                      IconButton(
                        onPressed: () {
                          showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: Text(audioDelete()),
                              content: Text(audioDeleteDescription()),
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
                          ).then((value) async {
                            if (value == true) {
                              ref.read(userAudioActionsProvider.notifier).remove(audioAction);
                              File storedAudioFilePath = File(audioAction.file);
                              await storedAudioFilePath.delete();
                              setState(() {
                                _audioLogger.info("Deleted audio file");
                              });
                            }
                          });
                        }, //TODO: Show dialog, then delete record and file.
                        tooltip: audioDelete(),
                        icon: const Icon(Icons.delete),
                      )
                    ],
                  ),
                  onTap: () => playSound(audioAction.file),
                );
              },
            ),
          ],
        ));
  }

  void editModal(BuildContext context, AudioAction audioAction) {
    showModalBottomSheet<AudioAction>(
      context: context,
      showDragHandle: true,
      enableDrag: true,
      isDismissible: true,
      isScrollControlled: true,
      clipBehavior: Clip.antiAlias,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.3,
          expand: false,
          builder: (BuildContext context, ScrollController scrollController) {
            return StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return ListView(
                  shrinkWrap: true,
                  controller: scrollController,
                  children: [
                    ListTile(
                      subtitle: TextField(
                        controller: TextEditingController(text: audioAction.name),
                        decoration: InputDecoration(border: const OutlineInputBorder(), labelText: sequencesEditName()),
                        maxLines: 1,
                        scrollPhysics: const NeverScrollableScrollPhysics(),
                        maxLength: 30,
                        autocorrect: false,
                        onSubmitted: (nameValue) {
                          setState(
                            () {
                              audioAction.name = nameValue;
                            },
                          );
                          ref.watch(userAudioActionsProvider.notifier).store();
                        },
                      ),
                    )
                  ],
                );
              },
            );
          },
        );
      },
    ).whenComplete(
      () {
        setState(
          () {},
        );
        ref.watch(userAudioActionsProvider.notifier).store();
      },
    );
  }
}
