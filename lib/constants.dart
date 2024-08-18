import 'dart:ui';

import 'package:tail_app/Backend/Definitions/Device/device_definition.dart';

const int kitsuneDelayRange = 1000;
const Duration animationTransitionDuration = Duration(milliseconds: 500);

// Settings labels
const String settings = 'settings';
const String kitsuneModeToggle = 'slightGearDelay';
const String appColor = 'appColor';
const String haptics = 'haptics';
const String keepAwake = 'keepAwake';
const String allowAnalytics = 'allowAnalytics';
const String allowErrorReporting = 'allowErrorReporting';
const String shouldDisplayReview = 'shouldDisplayReview';
const String hasDisplayedReview = 'hasDisplayReview';
const String gearDisconnectCount = 'reviewGearDisconnectCount';
const String showAccurateBattery = 'showAccurateBattery';
const String largerActionCardSize = 'largerActionCardSize';
const String hideTutorialCards = 'hideTutorialCards';
const String hasCompletedOnboarding = 'hasCompletedOnboardingVersion';
const String showDebugging = 'showDebugging';
const String alwaysScanning = 'alwaysScanning';
const String showDemoGear = 'showDemoGear';
const String earMoveSpeed = 'earMoveSpeed';
const String showAdvancedSettings = 'showAdvancedSettings';
const String dynamicConfigJsonString = 'dynamicConfigJsonString';
const String dynamicConfigStoredBuildNumber = 'dynamicConfigStoredBuildNumber';
const String casualModeDelayMin = 'casualModeDelayMin';
const String casualModeDelayMax = 'casualModeDelayMax';

// Settings Default value
const bool kitsuneModeDefault = false;
final int appColorDefault = const Color.fromARGB(255, 228, 110, 38).value;
const bool hapticsDefault = true;
const bool keepAwakeDefault = false;
const bool allowAnalyticsDefault = false;
const bool allowErrorReportingDefault = false;
const bool shouldDisplayReviewDefault = false;
const bool hasDisplayedReviewDefault = false;
const int gearDisconnectCountDefault = 0;
const bool showAccurateBatteryDefault = false;
const bool largerActionCardSizeDefault = false;
const bool hideTutorialCardsDefault = false;
const int hasCompletedOnboardingDefault = 0;
const bool showDebuggingDefault = false;
const bool alwaysScanningDefault = true;
const bool showDemoGearDefault = false;
const bool showAdvancedSettingsDefault = false;
const EarSpeed earMoveSpeedDefault = EarSpeed.fast;
const int casualModeDelayMinDefault = 15;
const int casualModeDelayMaxDefault = 120;

const String triggerBox = 'triggers';
const String sequencesBox = 'sequences';
const String devicesBox = 'devices';
const String favoriteActionsBox = 'favoriteActions';
const String audioActionsBox = 'audioActions';
const int hasCompletedOnboardingVersionToAgree = 2;
