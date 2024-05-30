import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/audio.dart';
import 'package:uuid/uuid.dart';

import '../intn_defs.dart';

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
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              type: FileType.audio,
            );
            if (result != null) {
              _audioLogger.info("Selected file");
              PlatformFile file = result.files.first;
              final Directory appDir = await getApplicationSupportDirectory();
              Directory audioDir = Directory("${appDir.path}/audio");
              await audioDir.create();
              File storedAudioFilePath = File("${audioDir.path}/${file.name}");
              _audioLogger.info("File path ${storedAudioFilePath.path}");
              File selectedFile = File(file.path!);
              _audioLogger.info("Selected file Path ${selectedFile.path}");
              Stream<List<int>> openRead = selectedFile.openRead();
              IOSink ioSinkWrite = storedAudioFilePath.openWrite();
              await ioSinkWrite.addStream(openRead);
              ioSinkWrite.close();
              _audioLogger.info("Wrote file to app storage");
              AudioAction action = AudioAction(name: file.name, uuid: const Uuid().v4(), file: storedAudioFilePath.path);
              ref.read(userAudioActionsProvider.notifier).add(action);
            }
            //Open File Picker
          },
          icon: const Icon(Icons.add),
          label: Text(audioAdd())),
      body: ListView.builder(
        itemCount: userAudioActions.length,
        itemBuilder: (context, index) {
          AudioAction audioAction = userAudioActions[index];
          return ListTile(
            title: Text(audioAction.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  tooltip: audioEdit(), //TODO: Edit record name
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  onPressed: () async {
                    ref.read(userAudioActionsProvider.notifier).remove(audioAction);
                    File storedAudioFilePath = File(audioAction.file);
                    await storedAudioFilePath.delete();
                    _audioLogger.info("Deleted audio file");
                  }, //TODO: Show dialog, then delete record and file.
                  tooltip: audioDelete(),
                  icon: const Icon(Icons.delete),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}
