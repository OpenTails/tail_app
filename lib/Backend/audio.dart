import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:built_collection/built_collection.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';

import '../constants.dart';
import 'Definitions/Action/base_action.dart';
import 'logging_wrappers.dart';

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
    Iterable<AudioAction> results = [];
    try {
      results = Hive.box<AudioAction>(audioActionsBox).values;
    } catch (e, s) {
      _audioLogger.severe("Unable to load audio: $e", e, s);
    }
    Hive.box<AudioAction>(audioActionsBox).close();
    _state = results.toList().build();
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
    LazyBox<AudioAction> lazyBox = await Hive.openLazyBox<AudioAction>(
      audioActionsBox,
    );
    await lazyBox.clear();
    await lazyBox.addAll(_state);
    notifyListeners();
  }
}
