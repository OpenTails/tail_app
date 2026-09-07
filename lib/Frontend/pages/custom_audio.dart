import 'dart:io';

import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:built_collection/built_collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:uuid/uuid.dart';

import '../../Backend/Action/base_action.dart';
import '../../Backend/audio.dart';
import '../Widgets/tutorial_card.dart';
import '../theme_helpers.dart';
import '../translation_string_definitions.dart';

final Logger _audioLogger = Logger('Audio');

class CustomAudio extends StatefulWidget {
  const CustomAudio({super.key});

  @override
  State<CustomAudio> createState() => _CustomAudioState();
}

class _CustomAudioState extends State<CustomAudio> {
  final waveformExtraction = WaveformExtractionController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(convertToUwU(audioPage()))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          _audioLogger.info("Opening file dialog");
          PlatformFile? result = await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: [
              'aac',
              'm4a',
              'flac',
              'wav',
              'avif',
              'mp3',
              'ac3',
            ],
          );
          if (result != null) {
            _audioLogger.info("Selected file");
            final Directory appDir = await getApplicationSupportDirectory();
            Directory audioDir = Directory("${appDir.path}/audio");
            await audioDir.create();
            File storedAudioFilePath = File("${audioDir.path}/${result.name}");
            _audioLogger
              ..info("File path ${storedAudioFilePath.path}")
              ..info("Selected file Path ${result.path}");
            Stream<List<int>> openRead = result.readAsByteStream();
            IOSink ioSinkWrite = storedAudioFilePath.openWrite();
            await ioSinkWrite.addStream(openRead);
            ioSinkWrite.close();
            _audioLogger.info("Wrote file to app storage");
            AudioAction action = AudioAction(
              name: result.name
                  .substring(0, result.name.lastIndexOf("."))
                  .replaceAll("_", " ")
                  .replaceAll("-", " "),
              uuid: const Uuid().v4(),
              file: storedAudioFilePath.path,
            );
            setState(() {
              UserAudioActions.instance.add(action);
            });
            analyticsEvent(name: "Add Custom Audio");
          }
          //Open File Picker
        },
        icon: const Icon(Symbols.add),
        label: Text(convertToUwU(audioAdd())),
      ),
      body: ListView(
        children: [
          PageInfoCard(text: audioTipCard()),
          ListenableBuilder(
            listenable: UserAudioActions.instance,
            builder: (context, child) {
              BuiltList<AudioAction> userAudioActions =
                  UserAudioActions.instance.state;

              return ListView.builder(
                itemCount: userAudioActions.length,
                shrinkWrap: true,
                padding: sectionedListViewPadding,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, index) {
                  AudioAction audioAction = userAudioActions[index];
                  return AudioListItem(audioAction: audioAction);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class AudioListItem extends StatefulWidget {
  final AudioAction audioAction;

  const AudioListItem({super.key, required this.audioAction});

  @override
  State<AudioListItem> createState() => _AudioListItemState();
}

class _AudioListItemState extends State<AudioListItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        title: Text(convertToUwU(widget.audioAction.name)),
        subtitle: FutureBuilder(
          key: Key(widget.audioAction.uuid),
          future: getWaveformData(widget.audioAction),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SizedBox(
                height: 90,
                child: Center(child: LinearProgressIndicator()),
              );
            } else {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return AudioFileWaveforms(
                    size: Size(constraints.maxWidth, 90),
                    playerController: PlayerController(),
                    waveformData: snapshot.data!,
                    seekOnTapUp: false,
                    enableSeekGesture: false,
                    waveformType: WaveformType.fitWidth,
                    playerWaveStyle: PlayerWaveStyle(
                      showSeekLine: false,
                      spacing: 5,
                      fixedWaveColor: ColorScheme.of(context).primary,
                    ),
                  );
                },
              );
            }
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                showModalBottomSheet<AudioAction>(
                  context: context,
                  showDragHandle: true,
                  enableDrag: true,
                  isDismissible: true,
                  isScrollControlled: true,
                  clipBehavior: Clip.antiAlias,
                  builder: (context) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: DraggableScrollableSheet(
                        initialChildSize: 0.3,
                        expand: false,
                        builder:
                            (
                              BuildContext context,
                              ScrollController scrollController,
                            ) {
                              return ListTile(
                                subtitle: TextField(
                                  controller:
                                      TextEditingController(
                                          text: widget.audioAction.name,
                                        )
                                        ..selection = TextSelection.collapsed(
                                          offset:
                                              widget.audioAction.name.length,
                                        ),
                                  autofocus: true,
                                  selectAllOnFocus: true,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    labelText: sequencesEditName(),
                                  ),
                                  maxLines: 1,
                                  scrollController: scrollController,
                                  onChanged: (nameValue) {
                                    setState(() {
                                      widget.audioAction.name = nameValue;
                                    });
                                  },
                                  onEditingComplete: () =>
                                      Navigator.pop(context),
                                ),
                              );
                            },
                      ),
                    );
                  },
                ).whenComplete(() {
                  setState(() {});
                  UserAudioActions.instance.store();
                });
              },
              tooltip: audioEdit(),
              icon: const Icon(Symbols.edit),
            ),
            IconButton(
              onPressed: () async {
                showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) => AlertDialog(
                    title: Text(convertToUwU(audioDelete())),
                    content: Text(convertToUwU(audioDeleteDescription())),
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
                    UserAudioActions.instance.remove(widget.audioAction);
                    File storedAudioFilePath = File(widget.audioAction.file);
                    await storedAudioFilePath.delete();
                    setState(() {
                      _audioLogger.info("Deleted audio file");
                    });
                  }
                });
              }, //TODO: Show dialog, then delete record and file.
              tooltip: audioDelete(),
              icon: const Icon(Symbols.delete),
            ),
          ],
        ),
        onTap: () async => playSound(widget.audioAction.file),
      ),
    );
  }
}
