import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../main.dart';

part 'Settings.g.dart';

@Riverpod(keepAlive: true)
class Preferences extends _$Preferences {
  @override
  PreferencesStore build() {
    try {
      if (prefs.containsKey("settings")) {
        String? result = prefs.getString("settings");
        if (result != null) {
          return PreferencesStore.fromJson(jsonDecode(result));
        }
      }
    } on Exception catch (e, s) {
      Flogger.e("error loading settings: $e", stackTrace: s);
    }
    return PreferencesStore();
  }

  void store() {
    prefs.setString("settings", const JsonEncoder.withIndent("    ").convert(state.toJson()));
  }
}

@JsonSerializable(explicitToJson: true, checked: true)
class PreferencesStore {
  PreferencesStore();

  @JsonKey(defaultValue: false)
  bool autoConnectNewDevices = false;
  @JsonKey(defaultValue: true)
  bool haptics = true;
  @JsonKey(defaultValue: false)
  bool alwaysScanning = false; //TODO: implement by listening to scan provider

  factory PreferencesStore.fromJson(Map<String, dynamic> json) => _$PreferencesStoreFromJson(json);

  Map<String, dynamic> toJson() => _$PreferencesStoreToJson(this);
}
