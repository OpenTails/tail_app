import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';

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
    Iterable<AudioAction> results = [];
    try {
      Box<AudioAction> box = await Hive.openBox<AudioAction>(audioActionsBox);
      results = box.values;
    } catch (e, s) {
      _audioLogger.severe("Unable to load audio: $e", e, s);
    }
    _state = results.toList().build();
    notifyListeners();
  }

  Future<void> add(AudioAction action) async {
    _state = _state.rebuild(
      (p0) => p0
        ..add(action)
        ..sort(),
    );
    store();
  }

  Future<void> remove(AudioAction action) async {
    _state = _state.rebuild(
      (p0) => p0.removeWhere((element) => element.uuid == action.uuid),
    );
    store();
  }

  bool contains(AudioAction action) {
    return _state.any((element) => element.uuid == action.uuid);
  }

  Future<void> store() async {
    _audioLogger.info("Storing Custom Audio");
    Box<AudioAction> box = await Hive.openBox<AudioAction>(audioActionsBox);
    await box.clear();
    await box.addAll(_state);
    notifyListeners();
  }
}
