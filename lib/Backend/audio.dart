import 'package:audioplayers/audioplayers.dart';
import 'package:built_collection/built_collection.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants.dart';
import 'Definitions/Action/base_action.dart';
import 'logging_wrappers.dart';

part 'audio.g.dart';

final Logger _audioLogger = Logger('Audio');

Future<void> playSound(String file) async {
  final player = AudioPlayer();
  try {
    await player.play(DeviceFileSource(file));
  } finally {
    player.dispose();
  }
}

@Riverpod(keepAlive: true)
class UserAudioActions extends _$UserAudioActions {
  @override
  BuiltList<AudioAction> build() {
    List<AudioAction> results = [];
    try {
      results = HiveProxy.getAll<AudioAction>(audioActionsBox).toList(growable: true);
    } catch (e, s) {
      _audioLogger.severe("Unable to load audio: $e", e, s);
    }
    return results.build();
  }

  Future<void> add(AudioAction action) async {
    state = state.rebuild(
      (p0) => p0
        ..add(action)
        ..sort(),
    );
    store();
  }

  Future<void> remove(AudioAction action) async {
    state = state.rebuild(
      (p0) => p0.removeWhere((element) => element.uuid == action.uuid),
    );
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
