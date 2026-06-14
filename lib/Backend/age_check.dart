import 'package:age_range_signals/age_range_signals.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:logging/logging.dart';
import 'package:universal_io/io.dart';

import '../Frontend/utils.dart';

Logger _logger = Logger("AgeCheck");

/// Assumes coshub should be shown unless the user is confirmed to be underage
Future<bool> shouldShowCoshub() async {
  bool showCoshub = true;

  // Age signals only available on mobile
  if (!isMobile) {
    //Firebase doesn't support web
    if (Platform.isLinux) {
      return false;
    }
    return true;
  }
  await AgeRangeSignals.instance.initialize(ageGates: [13]);

  // Check age signals
  try {
    if (Platform.isIOS) {
      IosDeviceInfo iosDeviceInfo = await DeviceInfoPlugin().iosInfo;
      if (int.parse(iosDeviceInfo.systemVersion.split(".")[0]) < 26) {
        _logger.info("IOS version below 26");
        return true;
      }
    }
    if (Platform.isAndroid) {
      GooglePlayServicesAvailability availability = await GoogleApiAvailability
          .instance
          .checkGooglePlayServicesAvailability();
      if (availability != GooglePlayServicesAvailability.success) {
        _logger.info("Play Services is not available");
        return true;
      }
    }
    final result = await AgeRangeSignals.instance.checkAgeSignals();

    switch (result.status) {
      case AgeSignalsStatus.verified:
        _logger.info('User is verified as above age threshold');
        break;
      case AgeSignalsStatus.supervised:
        _logger.info('User is under parental supervision');
        return false;
      case AgeSignalsStatus.supervisedApprovalPending:
        _logger.info('Waiting for guardian approval');
        return false;
      case AgeSignalsStatus.supervisedApprovalDenied:
        _logger.info('Guardian denied access');
        return false;
      case AgeSignalsStatus.declared:
        _logger.info('User declared their age through Google Play');
        return (result.ageLower ?? 0) >= 13;
      case AgeSignalsStatus.declined:
        _logger.info('User declined to share age information');
        return false;
      case AgeSignalsStatus.unknown:
        _logger.info('Age information is not available');
        break;
    }
  } catch (e, s) {
    _logger.warning("Failed to get user age", e, s);
  }
  return showCoshub;
}
