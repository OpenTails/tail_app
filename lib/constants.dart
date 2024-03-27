import 'package:flutter/material.dart';

const int kitsuneDelayRange = 1000;
const Duration animationTransitionDuration = Duration(milliseconds: 250);

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

// Settings Default value
const bool kitsuneModeDefault = false;
final int appColorDefault = Colors.orange.value;
const bool hapticsDefault = true;
const bool keepAwakeDefault = false;
const bool allowAnalyticsDefault = true;
const bool allowErrorReportingDefault = true;
const bool shouldDisplayReviewDefault = false;
const bool hasDisplayedReviewDefault = false;
const int gearDisconnectCountDefault = 0;
