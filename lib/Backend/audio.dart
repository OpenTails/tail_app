import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants.dart';
import 'Action/base_action.dart';

final Logger _audioLogger = Logger('Audio');

Future<void> playSound(String file) async {
  final player = AudioPlayer();
  try {
    if (await File(file).exists()) {
      await player.play(DeviceFileSource(file));
      await player.onPlayerComplete.first;
    }
  } finally {
    player.dispose();
  }
}

class UserAudioActions with ChangeNotifier {
  BuiltList<AudioAction> _state = BuiltList();

  BuiltList<AudioAction> get state => _state;

  static final UserAudioActions instance = UserAudioActions._internal();

  UserAudioActions._internal() {
    reload();
  }

  @visibleForTesting
  Future<void> reload() async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild('UserAudio.reload');
    Iterable<AudioAction> results = [];
    try {
      Box<AudioAction> box = await Hive.openBox<AudioAction>(audioActionsBox);
      results = box.values;
    } catch (e, s) {
      _audioLogger.severe("Unable to load audio: $e", e, s);
      await Hive.deleteBoxFromDisk(audioActionsBox);
    }
    _state = results.toList().build();
    notifyListeners();
    span?.finish();
  }

  Future<void> add(AudioAction action) async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild('UserAudio.add');
    _state = _state.rebuild(
      (p0) => p0
        ..add(action)
        ..sort(),
    );
    await store();
    span?.finish();
  }

  Future<void> remove(AudioAction action) async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild('UserAudio.remove');
    _state = _state.rebuild(
      (p0) => p0.removeWhere((element) => element.uuid == action.uuid),
    );
    await store();
    span?.finish();
  }

  bool contains(AudioAction action) {
    return _state.any((element) => element.uuid == action.uuid);
  }

  Future<void> store() async {
    final ISentrySpan? span = Sentry.getSpan()?.startChild('UserAudio.store');
    _audioLogger.info("Storing Custom Audio");
    Box<AudioAction> box = await Hive.openBox<AudioAction>(audioActionsBox);
    await box.clear();
    await box.addAll(_state);
    notifyListeners();
    span?.finish();
  }
}
