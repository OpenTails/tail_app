/*
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:tail_app/Backend/triggers/permissions.dart';

import '../../../Frontend/translation_string_definitions.dart';
import '../../../Frontend/utils.dart';
import '../sensor_definition.dart';
import '../sensor_definition_action_definition.dart';

final _mediaSession = FlutterMediaSession();

class MediaSessionTriggerDefinition extends TriggerDefinition {
  StreamSubscription<MediaAction>? streamSubscription;
  StreamSubscription<dynamic>? periodicStreamSubscription;

  MediaSessionTriggerDefinition() {
    super.name = triggerMediaControlsTitle;
    super.description = triggerMediaControlsDescription;
    super.icon = const Icon(Icons.play_arrow);
    super.requiredPermission = TriggerPermissionHandle(
      android: {Permission.notification},
    );
    super.uuid = "bb945cd3-2696-4c09-93f3-2a62a7fa5479";
    super.triggerActionDefinitions = [
      TriggerActionDef(
        name: "Play/Pause",
        translated: triggerMediaControlsPlayPause,
        uuid: "5c8cb71e-e7e3-4d62-af6d-4f8eabeb8bd1",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Forward",
        translated: triggerMediaControlsForward,
        uuid: "eb464780-2384-4a93-92dc-a579010b01f9",
        defaultActions: true,
      ),
      TriggerActionDef(
        name: "Rewind",
        translated: triggerMediaControlsRewind,
        uuid: "54a0a163-dd02-4abb-9831-70b656977d40",
        defaultActions: true,
      ),
    ];

    streamSubscription = _mediaSession.onMediaAction.listen((action) {
      debug = action.toString();
      switch (action) {
        case MediaAction.play:
        case MediaAction.pause:
        case MediaAction.stop:
          sendCommands("Play/Pause");
          break;
        case MediaAction.skipToNext:
        case MediaAction.fastForward:
          sendCommands("Forward");
          break;
        case MediaAction.skipToPrevious:
        case MediaAction.rewind:
          sendCommands("Rewind");
          break;
        default:
          break;
      }
    });
  }

  @override
  Future<bool> isSupported() async {
    if (platform.isLinux) {
      return false;
    }
    return true;
  }

  @override
  Future<void> onDisable() async {
    if (periodicStreamSubscription != null) {
      periodicStreamSubscription?.cancel();
      periodicStreamSubscription = null;
      await _mediaSession.deactivate();
    }
  }

  @override
  Future<void> onEnable() async {
    if (periodicStreamSubscription != null) {
      return;
    }
    await update();
    //await _mediaSession.setHandlesInterruptions(true);
    periodicStreamSubscription = Stream.periodic(Duration(seconds: 1)).listen((
      event,
    ) async {
      await update();
    });

    await _mediaSession.activate();
  }

  Future<void> update() async {
    await _mediaSession.updatePlaybackState(
      PlaybackState(
        status: PlaybackStatus.paused,
        position: Duration(seconds: 30), //
        // buffering,
        // paused, idle, error
      ),
    );
    await _mediaSession.updateMetadata(
      MediaMetadata(
        title: triggerMediaControlsTitle(),
        artist: title(),
        duration: Duration(minutes: 1),
      ),
    );
    await _mediaSession.updateAvailableActions({
      MediaAction.play,
      MediaAction.pause,
      MediaAction.skipToNext,
      MediaAction.skipToPrevious,
      MediaAction.fastForward,
      MediaAction.rewind,
      MediaAction.stop,
      MediaAction.seekTo,
    });
  }
}
*/
