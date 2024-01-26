import 'package:intl/intl.dart';

//generate file for translation. Run when adding new translations
//dart run intl_translation:extract_to_arb --locale=en --output-file='./lib/l10n/messages_en.arb' ./lib/Frontend/intnDefs.dart
//convert to dart TODO:
// dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/intnDefs.dart lib/l10n/*_messages.arb
String title() => Intl.message('Tail App', name: 'title', desc: 'The name of the app');

String subTitle() => Intl.message('All of the Tails', name: 'subTitle', desc: 'The sub-title which displays in the navigation drawer');

String manageDevices() => Intl.message('Manage Devices', name: 'manageDevices', desc: 'The screen where you pair and manage gear');

String doubleBack() => Intl.message('Press back again to leave', name: 'doubleBack', desc: 'A toast which appears when the back button is pressed at the main page');

String joyStickPage() => Intl.message('Joystick', name: 'joyStickPage', desc: 'The label and title of the joystick page');

String feedbackPage() => Intl.message('Feedback', name: 'feedbackPage', desc: 'The label and title of the feedback page');

String aboutPage() => Intl.message('About', name: 'aboutPage', desc: 'The label and title of the about page');

String settingsPage() => Intl.message('Settings', name: 'settingsPage', desc: 'The label and title of the settings page');

String actionsPage() => Intl.message('Actions', name: 'actionsPage', desc: 'The label and title of the action page');

String triggersPage() => Intl.message('Triggers', name: 'triggersPage', desc: 'The label and title of the trigger page');

String sequencesPage() => Intl.message('Sequences', name: 'sequencesPage', desc: 'The label and title of the sequences page');

// Triggers Page
String triggersSelectLabel() => Intl.message('Select an Trigger Type', name: 'triggersSelectLabel', desc: 'The title of the add trigger dialog');

String ok() => Intl.message('Ok', name: 'ok', desc: 'Ok on dialog boxes');

String cancel() => Intl.message('Cancel', name: 'cancel', desc: 'Cancel on dialog boxes');

String triggersAdd() => Intl.message('Add Trigger', name: 'triggersAdd', desc: 'Floating Action Button on the triggers page');

String deviceType() => Intl.message('Device Type', name: 'deviceType', desc: 'Title for the selector to select which device to send moves to');

String deviceTypeTail() => Intl.message('Tail', name: 'deviceTypeTail', desc: 'Tail option for the selector to select which device to send moves to');

String deviceTypeEars() => Intl.message('Ears', name: 'deviceTypeEars', desc: 'Ears option for the selector to select which device to send moves to');

String deviceTypeWings() => Intl.message('Wings', name: 'deviceTypeWings', desc: 'Wings option for the selector to select which device to send moves to');

// Sequences Page
String sequencesAdd() => Intl.message('New Sequence', name: 'sequencesAdd', desc: 'Floating Action Button on the sequences page');

String sequencesEdit() => Intl.message('Edit Sequence', name: 'sequencesEdit', desc: 'Label for the edit icon on a sequence');

String sequencesEditAdd() => Intl.message('Add Move', name: 'sequencesEditAdd', desc: 'Label for the add Floating Action Button on edit sequence page');

String sequencesEditName() => Intl.message('Name', name: 'sequencesEditName', desc: 'Label for the name field on sequence edit page');

String sequencesEditMove() => Intl.message('Move', name: 'sequencesEditMove', desc: 'Label for the move tab on sequence move edit page');

String sequencesEditDelay() => Intl.message('Delay', name: 'sequencesEditDelay', desc: 'Label for the delay tab on sequence move edit page');

String sequencesEditHome() => Intl.message('Home', name: 'sequencesEditHome', desc: 'Label for the home tab on sequence move edit page');

String sequencesEditLeftServo() => Intl.message('Left Servo', name: 'sequencesEditLeftServo', desc: 'Label for the left servo slider on the move tab of the move edit page');

String sequencesEditRightServo() => Intl.message('Right Servo', name: 'sequencesEditRightServo', desc: 'Label for the right servo slider on the move tab of the move edit page');

String sequencesEditSpeed() => Intl.message('Speed', name: 'sequencesEditSpeed', desc: 'Label for the speed selector on the move tab of the move edit page');

String sequencesEditSpeedFast() => Intl.message('Fast', name: 'sequencesEditSpeedFast', desc: 'Label for the Fast speed selector on the move tab of the move edit page');

String sequencesEditSpeedSlow() => Intl.message('Slow', name: 'sequencesEditSpeedSlow', desc: 'Label for the Slow speed selector on the move tab of the move edit page');

String sequencesEditEasing() => Intl.message('Easing Type', name: 'sequencesEditEasing', desc: 'Label for the easing selector on the move tab of the move edit page');

String sequencesEditTime() => Intl.message('Time', name: 'sequencesEditTime', desc: 'Label for the time slider on the delay tab of the move edit page');

String sequencesEditHomeLabel() => Intl.message('Home the Gear', name: 'sequencesEditHomeLabel', desc: 'Label on the home tab of the move edit page');

String sequenceEditListDelayLabel(int howMany) => Intl.message(
      '''Intl.plural(howMany, one: ' Delay next move for $howMany second.', other: 'Delay next move for $howMany seconds.')''',
      name: 'sequenceEditListDelayLabel',
      args: [howMany],
      desc: 'Delay move label on the edit sequences page.',
      examples: const {'howMany': '42'},
    );
//Actions Page
String actionsNoGear() => Intl.message('No Gear Connected', name: 'actionsNoGear', desc: 'Label on the actions page when no gear is connected');

String actionsCategoryCalm() => Intl.message('Calm and Relaxed', name: 'actionsCategoryCalm', desc: 'calm action group label');

String actionsCategoryFast() => Intl.message('Fast and Excited', name: 'actionsCategoryFast', desc: 'fast action group label');

String actionsCategoryTense() => Intl.message('Frustrated and Tense', name: 'actionsCategoryTense', desc: 'tense action group label');

String actionsCategoryGlowtip() => Intl.message('GlowTip', name: 'actionsCategoryGlowtip', desc: 'glowtip action group label');

String actionsCategoryEars() => Intl.message('Ears', name: 'actionsCategoryEars', desc: 'ears action group label');

//Settings
String settingsHapticsToggleTitle() => Intl.message('Haptic Feedback', name: 'settingsHapticsToggleTitle', desc: 'Settings page haptic feedback toggle title');

String settingsHapticsToggleSubTitle() => Intl.message('Enable vibration when an action or sequence is tapped', name: 'settingsHapticsToggleSubTitle', desc: 'Settings page haptic feedback toggle subtitle');

String settingsAutoConnectToggleTitle() => Intl.message('Automatically Scan for known gear', name: 'settingsAutoConnectToggleTitle', desc: 'Settings page auto connect toggle title');

String settingsAutoConnectToggleSubTitle() => Intl.message('Scan for known gear automatically, This only works when the app is open and will drain your battery faster!', name: 'settingsAutoConnectToggleSubTitle', desc: 'Settings page auto connect toggle subtitle');

String settingsErrorReportingToggleTitle() => Intl.message('Automatic error reporting', name: 'settingsErrorReportingToggleTitle', desc: 'Settings page error reporting toggle title');

String settingsErrorReportingToggleSubTitle() => Intl.message('Automatically reports errors to sentry', name: 'settingsErrorReportingToggleSubTitle', desc: 'Settings page error reporting toggle subtitle');

//Move List
String manageDevicesAutoMoveTitle() => Intl.message('Auto Move', name: 'manageDevicesAutoMoveTitle', desc: 'Auto move toggle title when managing a device');

String manageDevicesAutoMoveSubTitle() => Intl.message('The tail will select a random move, pausing for a random number of seconds between each move', name: 'manageDevicesAutoMoveSubTitle', desc: 'Auto move toggle subtitle when managing a device');

String manageDevicesAutoMoveGroupsTitle() => Intl.message('Move Groups', name: 'manageDevicesAutoMoveGroupsTitle', desc: 'Auto move group selector title when managing a device');

String manageDevicesAutoMoveGroupsFast() => Intl.message('Fast', name: 'manageDevicesAutoMoveGroupsFast', desc: 'Auto move group fast option label when managing a device');

String manageDevicesAutoMoveGroupsCalm() => Intl.message('Calm', name: 'manageDevicesAutoMoveGroupsCalm', desc: 'Auto move group  calm option label when managing a device');

String manageDevicesAutoMoveGroupsFrustrated() => Intl.message('Frustrated', name: 'manageDevicesAutoMoveGroupsFrustrated', desc: 'Auto move group frustrated option label when managing a device');

String manageDevicesAutoMovePauseTitle() => Intl.message('Pause between moves', name: 'manageDevicesAutoMovePauseTitle', desc: 'Auto move pause slider title when managing a device');

String manageDevicesAutoMovePauseSliderLabel(int howMany) => Intl.message(
      '''Intl.plural(howMany, one: '$howMany second', other: '$howMany seconds')''',
      name: 'manageDevicesAutoMovePauseSliderLabel',
      args: [howMany],
      desc: 'Auto move pause slider title when managing a device.',
      examples: const {'howMany': '42'},
    );

String manageDevicesAutoMoveNoPhoneTitle() => Intl.message('No-Phone-Mode Start Delay', name: 'manageDevicesAutoMoveNoPhoneTitle', desc: 'Auto move no-phone mode slider title when managing a device');

String manageDevicesAutoMoveNoPhoneSliderLabel(int howMany) => Intl.message(
      '''Intl.plural(howMany, one: '$howMany minute', other: '$howMany minutes')''',
      name: 'manageDevicesAutoMoveNoPhoneSliderLabel',
      args: [howMany],
      desc: 'Auto move no phone slider label when managing a device.',
      examples: const {'howMany': '42'},
    );

String manageDevicesDisconnect() => Intl.message('Disconnect', name: 'manageDevicesDisconnect', desc: 'manage devices disconnect button title when managing a device');

String manageDevicesForget() => Intl.message('Forget', name: 'manageDevicesForget', desc: 'manage devices forget button title when managing a device');

String scanDevicesAutoConnectTitle() => Intl.message('Automatically connect to new devices', name: 'scanDevicesAutoConnectTitle', desc: 'scan for devices auto connect toggle title when scanning for a device');

String scanDevicesScanMessage() => Intl.message('Scanning for gear. Please make sure your gear is powered on and nearby', name: 'scanDevicesScanMessage', desc: 'scan for devices scan in progress message when scanning for a device');
