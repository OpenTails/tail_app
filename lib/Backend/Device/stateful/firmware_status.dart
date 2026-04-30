import 'package:flutter/foundation.dart';
import 'package:tail_app/Backend/Device/ota/update_info.dart';
import 'package:tail_app/Backend/utilities/version.dart';

class FirmwareStatus with ChangeNotifier {
  Version _firmwareVersion = Version();

  Version get firmwareVersion => _firmwareVersion;

  set firmwareVersion(Version value) {
    _firmwareVersion = value;
    notifyListeners();
  }

  String _hardwareVersion = "";

  String get hardwareVersion => _hardwareVersion;

  set hardwareVersion(String value) {
    _hardwareVersion = value;
    notifyListeners();
  }

  FWInfo? remoteFirmwareInfo;

  bool hasUpdate = false;
  bool mandatoryOtaRequired = false;

  void reset() {
    firmwareVersion = Version();
    hardwareVersion = "";
    hasUpdate = false;
    mandatoryOtaRequired = false;
  }
}
