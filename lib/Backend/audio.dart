import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants.dart';
import 'Definitions/Action/base_action.dart';
import 'logging_wrappers.dart';

part 'audio.g.dart';

final Logger _audioLogger = Logger('Audio');

Future<void> setUpAudio() async {
  _audioLogger.info("Setting up audio session");
  final session = await AudioSession.instance;
  await session.configure(
    const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.ambient,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.unknown,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ),
  );
}

Future<void> playSound(String file) async {
  _audioLogger.info("Playing sound file $file");
  final AudioPlayer player = AudioPlayer();
  await player.setFilePath(file);
  await player.play();
  await player.processingStateStream.where((event) => event == ProcessingState.completed).first;
  _audioLogger.info("Finished playing sound file $file");
  await player.dispose();
}

@Riverpod(keepAlive: true)
class UserAudioActions extends _$UserAudioActions {
  @override
  List<AudioAction> build() {
    List<AudioAction> results = [];
    try {
      results = HiveProxy.getAll<AudioAction>(audioActionsBox).toList(growable: true);
    } catch (e, s) {
      _audioLogger.severe("Unable to load audio: $e", e, s);
    }
    return results;
  }

  Future<void> add(AudioAction action) async {
    state
      ..add(action)
      ..sort();
    store();
  }

  Future<void> remove(AudioAction action) async {
    state.removeWhere((element) => element.uuid == action.uuid);
    store();
  }

  bool contains(AudioAction action) {
    return state.any((element) => element.uuid == action.uuid);
  }

  Future<void> store() async {
    _audioLogger.info("Storing Custom Audio");
    await HiveProxy.clear<AudioAction>(audioActionsBox);
    await HiveProxy.addAll<AudioAction>(audioActionsBox, state);
  }
}
