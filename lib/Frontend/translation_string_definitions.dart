import 'package:intl/intl.dart';

//generate file for translation. Run when adding new translations
//dart run intl_translation:extract_to_arb --locale=en --output-file='./lib/l10n/messages_en.arb' ./lib/Frontend/translation_string_definitions.dart
//convert to dart
// dart run intl_translation:generate_from_arb --output-dir=lib/l10n --no-use-deferred-loading lib/Frontend/translation_string_definitions.dart lib/l10n/*.arb
String title() => Intl.message('The Tail Company', name: 'title', desc: 'The name of the app');

String homeNewsTitle() => Intl.message('Fresh from the Tail Blog', name: 'homeNewsTitle', desc: 'The title header for the news in the home screen when no gear is connected');

String homeWelcomeMessageTitle() => Intl.message('Welcome to the Tail Company App', name: 'homeWelcomeMessageTitle', desc: 'The welcome message title on the home screen when no gear is connected');

String homeContinuousScanningOffDescription() =>
    Intl.message('Swipe horizontally on the known device area above to begin scanning. You can turn on continuous scanning in settings.', name: 'homeContinuousScanningOffDescription', desc: 'The welcome message title on the home screen when no gear is connected');

String homeWelcomeMessage() => Intl.message('You can control, explore and update all your Tail Co gear right here. There are instructions and guides available too. Happy Wagging!', name: 'homeWelcomeMessage', desc: 'The welcome message on the home screen when no gear is connected');

String joyStickPage() => Intl.message('Joystick', name: 'joyStickPage', desc: 'The label and title of the joystick page');

String joyStickPageDescription() => Intl.message('Directly control the gear position.', name: 'joyStickPageDescription', desc: 'The description of the joystick page on the more page');

String feedbackPage() => Intl.message('Send Feedback', name: 'feedbackPage', desc: 'The label and title of the feedback page');

String audioPage() => Intl.message('Custom Sounds', name: 'audioPage', desc: 'The label and title of the custom audio management page');

String aboutPage() => Intl.message('About', name: 'aboutPage', desc: 'The label and title of the about page');

String settingsPage() => Intl.message('Settings', name: 'settingsPage', desc: 'The label and title of the settings page');

String settingsDescription() => Intl.message('Change app color, configure Haptics, and more', name: 'settingsDescription', desc: 'The description of the settings page on the more page');

//String actionsPage() => Intl.message('Actions', name: 'actionsPage', desc: 'The label and title of the action page');

String homePage() => Intl.message('Actions', name: 'actionsPage', desc: 'The label and title of the action page');

String triggersPage() => Intl.message('Triggers', name: 'triggersPage', desc: 'The label and title of the trigger page');

String sequencesPage() => Intl.message('Custom Actions', name: 'sequencesPage', desc: 'The label and title of the sequences page');

String sequencesPageDescription() => Intl.message('Create custom Actions for your gear', name: 'sequencesPageDescription', desc: 'The description of the sequences page link on the more page');

// Triggers Page
String triggersSelectLabel() => Intl.message('Select a Trigger Type', name: 'triggersSelectLabel', desc: 'The title of the add trigger dialog');

String triggersSelectClearLabel() => Intl.message('Select None', name: 'triggersSelectClearLabel', desc: 'The button label on the trigger select screen for clearing the selected actions');

String triggersSelectAllLabel() => Intl.message('Select All', name: 'triggersSelectAllLabel', desc: 'The button label on the trigger select screen for clearing the selected actions');

String triggersSelectSaveLabel() => Intl.message('Save Actions', name: 'triggersSelectSaveLabel', desc: 'The button label on the trigger select screen for saving the selected actions');

String ok() => Intl.message('Ok', name: 'ok', desc: 'Ok on dialog boxes');

String cancel() => Intl.message('Cancel', name: 'cancel', desc: 'Cancel on dialog boxes');

String triggersAdd() => Intl.message('Add Trigger', name: 'triggersAdd', desc: 'Floating Action Button on the triggers page');

String deviceType() => Intl.message('Which gear should this apply to?', name: 'deviceType', desc: 'Title for the selector to select which device to send moves to');

String deviceTypeTail() => Intl.message('Tail', name: 'deviceTypeTail', desc: 'Tail option for the selector to select which device to send moves to');

String deviceTypeMiniTail() => Intl.message('Mini Tail', name: 'deviceTypeMiniTail', desc: 'Tail option for the selector to select which device to send moves to');

String deviceTypeEars() => Intl.message('Ears', name: 'deviceTypeEars', desc: 'Ears option for the selector to select which device to send moves to');

String deviceTypeWings() => Intl.message('Wings', name: 'deviceTypeWings', desc: 'Wings option for the selector to select which device to send moves to');

// Sequences Page
String sequencesAdd() => Intl.message('New Action', name: 'sequencesAdd', desc: 'Floating Action Button on the sequences page');

String sequencesEdit() => Intl.message('Edit Action', name: 'sequencesEdit', desc: 'Label for the edit icon on a sequence');

String sequencesEditAdd() => Intl.message('Add Move', name: 'sequencesEditAdd', desc: 'Label for the add Floating Action Button on edit sequence page');

String sequencesEditName() => Intl.message('Name', name: 'sequencesEditName', desc: 'Label for the name field on sequence edit page');

String sequencesEditMove() => Intl.message('Move', name: 'sequencesEditMove', desc: 'Label for the move tab on sequence move edit page');

String sequencesEditDelay() => Intl.message('Delay', name: 'sequencesEditDelay', desc: 'Label for the delay tab on sequence move edit page');

String sequencesEditLeftServo() => Intl.message('Position of the Left Servo', name: 'sequencesEditLeftServo', desc: 'Label for the left servo slider on the move tab of the move edit page');

String sequencesEditRightServo() => Intl.message('Position of the Right Servo', name: 'sequencesEditRightServo', desc: 'Label for the right servo slider on the move tab of the move edit page');

String sequencesEditSpeed() => Intl.message('How Fast should the gear move to this position?', name: 'sequencesEditSpeed', desc: 'Label for the speed selector on the move tab of the move edit page');

String sequencesEditEasing() => Intl.message('Easing Type', name: 'sequencesEditEasing', desc: 'Label for the easing selector on the move tab of the move edit page');

String sequencesEditTime() => Intl.message('How long to wait before going to the next move in this Custom Action', name: 'sequencesEditTime', desc: 'Label for the time slider on the delay tab of the move edit page');

String sequencesEditHomeLabel() => Intl.message('Home the Gear', name: 'sequencesEditHomeLabel', desc: 'Label on the home tab of the move edit page');

String sequencesEditDeleteTitle() => Intl.message('Delete Action', name: 'sequencesEditDeleteTitle', desc: 'Title of the dialog on the sequence edit page to delete the sequence');

String sequencesEditDeleteDescription() => Intl.message('Are you sure you want to delete this action?', name: 'sequencesEditDeleteDescription', desc: 'Message of the dialog on the sequence edit page to delete the sequence');

String sequenceEditListDelayLabel(int howMany) => Intl.message(
      'Delay next move for $howMany ms.',
      name: 'sequenceEditListDelayLabel',
      args: [howMany],
      desc: 'Delay move label on the edit sequences page.',
      examples: const {'howMany': '42'},
    );
//Actions Page
String actionsNoBluetooth() => Intl.message('Bluetooth is unavailable', name: 'actionsNoBluetooth', desc: 'Label on the actions page when bluetooth is unavailable');

String actionsCategoryCalm() => Intl.message('Calm and Relaxed', name: 'actionsCategoryCalm', desc: 'calm action group label');

String actionsCategoryFast() => Intl.message('Fast and Excited', name: 'actionsCategoryFast', desc: 'fast action group label');

String actionsCategoryTense() => Intl.message('Frustrated and Tense', name: 'actionsCategoryTense', desc: 'tense action group label');

String actionsCategoryGlowtip() => Intl.message('GlowTip', name: 'actionsCategoryGlowtip', desc: 'glowtip action group label');

String actionsSelectScreen() => Intl.message('Select Actions', name: 'actionsSelectScreen', desc: 'Title for action select menu on triggers page');
//Settings
String settingsHapticsToggleTitle() => Intl.message('Haptic Feedback', name: 'settingsHapticsToggleTitle', desc: 'Settings page haptic feedback toggle title');

String settingsHapticsToggleSubTitle() => Intl.message('Enable vibration when an action is tapped', name: 'settingsHapticsToggleSubTitle', desc: 'Settings page haptic feedback toggle subtitle');

String settingsAlwaysScanningToggleTitle() => Intl.message('Always scan for known gear', name: 'settingsAlwaysScanningToggleTitle', desc: 'Settings page always scanning toggle title');

String settingsAlwaysScanningToggleSubTitle() => Intl.message('Continuously scan for known gear. When disabled, you must swipe on the gear bar to scan.', name: 'settingsAlwaysScanningToggleSubTitle', desc: 'Settings page always scanning toggle subtitle');

String settingsKeepScreenOnToggleTitle() => Intl.message('Keep Screen On', name: 'settingsKeepScreenOnToggleTitle', desc: 'Settings page Keep Awake toggle title');

String settingsKeepScreenOnToggleSubTitle() => Intl.message('This mode stops the screen from switching off whilst your gear is connected', name: 'settingsKeepScreenOnToggleSubTitle', desc: 'Settings page Keep Awake toggle subtitle');

String settingsKitsuneToggleTitle() => Intl.message('Kitsune Mode', name: 'settingsKitsuneToggleTitle', desc: 'Settings page Kitsune mode toggle title');

String settingsKitsuneToggleSubTitle() =>
    Intl.message('If you connect many instances of the same devices, this mode will add random pauses to their move-start times, giving it a different visual effect.', name: 'settingsKitsuneToggleSubTitle', desc: 'Settings page show battery percentage toggle subtitle');

String settingsBatteryPercentageToggleTitle() => Intl.message('Show Battery %', name: 'settingsBatteryPercentageToggleTitle', desc: 'Settings page Battery Percentage mode toggle title');

String settingsBatteryPercentageToggleSubTitle() => Intl.message('Show the actual battery level instead of an icon', name: 'settingsBatteryPercentageToggleSubTitle', desc: 'Settings page show battery percentage toggle subtitle');

String settingsLargerCardsToggleTitle() => Intl.message('Larger Cards', name: 'settingsLargerCardsToggleTitle', desc: 'Settings page Larger cards toggle title');

String settingsLargerCardsToggleSubTitle() => Intl.message('Makes the action cards bigger for easier tapping', name: 'settingsLargerCardsToggleSubTitle', desc: 'Settings page show larger cards toggle subtitle');

String settingsErrorReportingToggleTitle() => Intl.message('Automatic error reporting', name: 'settingsErrorReportingToggleTitle', desc: 'Settings page error reporting toggle title');

String settingsErrorReportingToggleSubTitle() => Intl.message('Sends error reports to Sentry', name: 'settingsErrorReportingToggleSubTitle', desc: 'Settings page error reporting toggle subtitle');

String settingsTutorialCardToggleTitle() => Intl.message('Hide Tutorial Cards', name: 'settingsTutorialCardToggleTitle', desc: 'Settings page tutorial card display toggle title');

String settingsTutorialCardToggleSubTitle() => Intl.message('Hide the various tutorial cards throughout the app', name: 'settingsTutorialCardToggleSubTitle', desc: 'Settings page tutorial card display toggle subtitle');

String settingsAnalyticsToggleTitle() => Intl.message('Allow Anonymous Analytics', name: 'settingsAnalyticsToggleTitle', desc: 'Settings page analytics reporting toggle title');

String settingsAnalyticsToggleSubTitle() => Intl.message('Report non identifying feature usage to Plausible for enhancing the app', name: 'settingsAnalyticsToggleSubTitle', desc: 'Settings page analytics reporting toggle subtitle');

String settingsNewsletterToggleTitle() => Intl.message('Allow Tail Blog Notifications', name: 'settingsNewsletterToggleTitle', desc: 'Settings page newsletter notification toggle title');

String settingsNewsletterToggleSubTitle() => Intl.message('Automatically receive notifications when there is a new Tail Blog post', name: 'settingsNewsletterToggleSubTitle', desc: 'Settings page newsletter notification toggle subtitle');

String settingsAppColor() => Intl.message('App Color', name: 'settingsAppColor', desc: 'Settings page app color picker button title');

String manageDevicesBatteryGraphTitle() => Intl.message('Battery Graph', name: 'manageDevicesBatteryGraphTitle', desc: 'battery graph expansion tile title');

String manageDevicesDisconnect() => Intl.message('Disconnect', name: 'manageDevicesDisconnect', desc: 'manage devices disconnect button title when managing a device');

String manageDevicesConnect() => Intl.message('Connect', name: 'manageDevicesConnect', desc: 'manage devices connect button title when managing a device');

String manageDevicesShutdown() => Intl.message('Shut Down', name: 'manageDevicesShutdown', desc: 'manage devices shutdown button title when managing a device');

String manageDevicesColor() => Intl.message('Gear Color', name: 'manageDevicesColor', desc: 'manage devices color picker button title when managing a device');

String manageDevicesForget() => Intl.message('Forget', name: 'manageDevicesForget', desc: 'manage devices forget button title when managing a device');

String manageDevicesOtaButton() => Intl.message('Tap to update firmware', name: 'manageDevicesOtaButton', desc: 'manage devices ota available button');

String scanDevicesTitle() => Intl.message('Scan For New Gear', name: 'scanDevicesTitle', desc: 'button which opens the scan window');

String scanDevicesFoundTitle() => Intl.message('Found Gear. Tap the gear name to connect', name: 'scanDevicesFoundTitle', desc: 'Title when gear is found on the scan for new gear page');

String scanDevicesScanMessage() => Intl.message('Scanning for gear. Please make sure your gear is powered on and nearby', name: 'scanDevicesScanMessage', desc: 'scan for devices scan in progress message when scanning for a device');

//Triggers
String triggerWalkingTitle() => Intl.message('Walking', name: 'triggerWalkingTitle', desc: 'Walking/Step trigger title');

String triggerWalkingDescription() => Intl.message('Trigger an action on walking', name: 'triggerWalkingDescription', desc: 'Walking/Step trigger description');

String triggerWalkingStopped() => Intl.message('Stopped', name: 'triggerWalkingStopped', desc: 'Walking/Step trigger Stopped action label');

String triggerWalkingStep() => Intl.message('Step', name: 'triggerWalkingStep', desc: 'Walking/Step trigger Step action label');

String triggerCoverTitle() => Intl.message('Cover', name: 'triggerCoverTitle', desc: 'Cover trigger Title');

String triggerCoverDescription() => Intl.message("Trigger an action by covering the proximity sensor", name: 'triggerCoverDescription', desc: 'Cover trigger description');

String triggerCoverNear() => Intl.message("Device Covered", name: 'triggerCoverNear', desc: 'Cover trigger near action label');

String triggerCoverFar() => Intl.message("Device Uncovered", name: 'triggerCoverFar', desc: 'Cover trigger far action label');

String triggerRandomButtonTitle() => Intl.message("Casual Mode", name: 'triggerRandomButtonTitle', desc: 'Casual Mode trigger title');

String triggerRandomButtonDescription() => Intl.message("Randomly play a selected action", name: 'triggerRandomButtonDescription', desc: 'Casual Mode trigger description');

String triggerRandomAction() => Intl.message("Action", name: 'triggerRandomAction', desc: 'Casual Mode trigger action label');

String triggerVolumeButtonTitle() => Intl.message("Volume Buttons", name: 'triggerVolumeButtonTitle', desc: 'Volume Button trigger title');

String triggerVolumeButtonDescription() => Intl.message("Trigger an action by pressing the volume button", name: 'triggerVolumeButtonDescription', desc: 'Volume Button trigger description');

String triggerVolumeButtonVolumeUp() => Intl.message("Volume Up", name: 'triggerVolumeButtonVolumeUp', desc: 'Volume Button trigger volume up action label');

String triggerVolumeButtonVolumeDown() => Intl.message("Volume Down", name: 'triggerVolumeButtonVolumeDown', desc: 'Volume Button trigger volume down action label');

String triggerShakeTitle() => Intl.message("Shake", name: 'triggerShakeTitle', desc: 'Shake trigger title');

String triggerShakeDescription() => Intl.message("Trigger an action by shaking your device", name: 'triggerShakeDescription', desc: 'Shake trigger description');

String triggerProximityTitle() => Intl.message("Nearby Gear", name: 'triggerProximityTitle', desc: 'Proximity trigger title');

String triggerProximityDescription() => Intl.message("Trigger an action if gear is nearby", name: 'triggerProximityDescription', desc: 'Proximity trigger description');

String triggerActionNotSet() => Intl.message("No Action Set", name: 'triggerActionNotSet', desc: 'Trigger action label when no action set');

String triggerEarMicTitle() => Intl.message("EarGear Mic", name: 'triggerEarMicTitle', desc: 'EarGear internal mic trigger title');

String triggerEarMicDescription() => Intl.message("Trigger an action when EarGear detects sound", name: 'triggerEarMicDescription', desc: 'EarGear internal mic trigger description');

String triggerEarMicSound() => Intl.message("Sound Detected", name: 'triggerEarMicSound', desc: 'EarGear internal mic trigger sound detected action label');

String triggerEarTiltTitle() => Intl.message("EarGear Tilt Sensor", name: 'triggerEarTiltTitle', desc: 'EarGear internal gesture sensor trigger title');

String triggerEarTiltDescription() => Intl.message("Trigger an action when EarGear detects tilt", name: 'triggerEarTiltDescription', desc: 'EarGear internal mic trigger description');

String triggerEarTiltLeft() => Intl.message("Left Tilt", name: 'triggerEarTiltLeft', desc: 'EarGear internal gesture sensor trigger left tilt detected action label');

String triggerEarTiltRight() => Intl.message("Right Tilt", name: 'triggerEarTiltRight', desc: 'EarGear internal gesture sensor trigger right tilt detected action label');

String triggerEarTiltForward() => Intl.message("Forward Tilt", name: 'triggerEarTiltForward', desc: 'EarGear internal gesture sensor trigger forward tilt detected action label');

String triggerEarTiltBackward() => Intl.message("Backward Tilt", name: 'triggerEarTiltBackward', desc: 'EarGear internal gesture sensor trigger backward tilt detected action label');

String sequenceEditRepeatTitle() => Intl.message("How many times to repeat this Action?", name: 'sequenceEditRepeatTitle', desc: 'Title for slider on sequence edit page to set how many times to repeat the sequence');

String moreManualResponsibleWaggingTitle() => Intl.message("Responsible Wagging", name: 'moreManualResponsibleWaggingTitle', desc: 'Title for Responsible wagging manual button on More page');

String moreManualMiTailTitle() => Intl.message("MiTail Manual", name: 'moreManualMiTailTitle', desc: 'Title for MiTail manual button on More page');

String moreManualEargearTitle() => Intl.message("EarGear Manual", name: 'moreManualEargearTitle', desc: 'Title for EarGear manual button on More page');

String moreManualFlutterWingsTitle() => Intl.message("FlutterWings Manual", name: 'moreManualFlutterWingsTitle', desc: 'Title for FlutterWings manual button on More page');

String moreManualTitle() => Intl.message("Manuals", name: 'moreManualTitle', desc: 'Title for manual header on More page');

String moreManualSubTitle() => Intl.message('Tap to view', name: 'moreManualSubTitle', desc: 'Subtitle for each manual on More page');

String moreUsefulLinksTitle() => Intl.message("Useful Links", name: 'moreUsefulLinksTitle', desc: 'Title for Useful Links header on More page');

String morePrivacyPolicyLinkTitle() => Intl.message("Privacy Policy", name: 'morePrivacyPolicyLinkTitle', desc: 'Title for Privacy policy link under Useful Links on More page');

String homeChangelogLinkTitle() => Intl.message("Changelog", name: 'homeChangelogLinkTitle', desc: 'Title for Changelog on Home page');

String moreTitle() => Intl.message("More", name: 'moreTitle', desc: 'Title for More page');

String otaTitle() => Intl.message("Update Gear", name: 'otaTitle', desc: 'Title for OTA page');

String otaChangelogLabel() => Intl.message("Firmware Changelog", name: 'otaChangelogLabel', desc: 'Label for changelog section of OTA page');

String otaDownloadButtonLabel() => Intl.message("Begin OTA Update", name: 'otaDownloadButtonLabel', desc: 'Label for download firmware button at bottom of OTA page');

String otaInProgressTitle() => Intl.message("Updating Gear. Please do not turn off your gear or close the app", name: 'otaInProgressTitle', desc: 'Label for ota in progress');

String otaCompletedTitle() => Intl.message("Update Completed", name: 'otaCompletedTitle', desc: 'Title for the text that appears when an OTA update is completed');

String otaFailedTitle() => Intl.message("Update Failed. Please restart your gear and try again", name: 'otaFailedTitle', desc: 'Title for the text that appears when an OTA update has failed');

String otaLowBattery() => Intl.message("Low Battery. Please charge your gear to at least 50%", name: 'otaLowBattery', desc: 'Title for the text that appears when an OTA update was blocked due to low battery');

String triggerInfoDescription() => Intl.message('Triggers automatically send actions to your gear. You can have multiple triggers active at the same time. Tap on a trigger to edit it, Use the toggle on the left to enable the trigger.',
    name: 'triggerInfoDescription', desc: 'Description for what a trigger is and how to use them on the triggers page');

String triggerInfoEditActionDescription() => Intl.message("Tap the pencil to select the Action to play when the event happens. An action will be randomly selected that is compatible with connected gear. GlowTip and Sound actions will trigger alongside Move actions.",
    name: 'triggerInfoEditActionDescription', desc: 'Instruction on how to select an action on the trigger edit page');

String sequencesInfoDescription() => Intl.message('Custom Actions allow you to make your own Actions for gear. Tapping on a Custom Action will play it. Tap the pencil to edit a Custom Action. Please make sure your gear firmware is up to date.',
    name: 'sequencesInfoDescription', desc: 'Description for what a custom action is and how to use them on the Custom Actions page');

String sequencesInfoEditDescription() => Intl.message('Each Custom Action consists of 1-6 moves and may repeat up to 5 times. You can long press a move to re-order it.', name: 'sequencesInfoEditDescription', desc: 'Description for making a custom action on the edit Custom Action page');

String onboardingPrivacyPolicyDescription() =>
    Intl.message("While the data collected is anonymous and can't be used to identify a specific user, you still need to accept the privacy policy", name: 'onboardingPrivacyPolicyDescription', desc: 'Description for there being a privacy policy on the onboarding screen');

String onboardingPrivacyPolicyViewButtonLabel() => Intl.message("View Privacy Policy", name: 'onboardingPrivacyPolicyViewButtonLabel', desc: 'Button label to view privacy policy on the onboarding screen');

String onboardingPrivacyPolicyAcceptButtonLabel() => Intl.message("Accept Privacy Policy", name: 'onboardingPrivacyPolicyAcceptButtonLabel', desc: 'Button label to accept privacy policy on the onboarding screen');

String onboardingBluetoothTitle() => Intl.message("Bluetooth", name: 'onboardingBluetoothTitle', desc: 'Title for bluetooth section on the onboarding screen');

String onboardingBluetoothDescription() => Intl.message("Bluetooth permission is required to connect to gear", name: 'onboardingBluetoothDescription', desc: 'Description for bluetooth section on the onboarding screen');

String onboardingBluetoothRequestButtonLabel() => Intl.message("Grant Permission", name: 'onboardingBluetoothRequestButtonLabel', desc: 'Label for the button to request bluetooth permission on the onboarding screen');

String onboardingBluetoothEnableButtonLabel() => Intl.message("Turn On Bluetooth", name: 'onboardingBluetoothEnableButtonLabel', desc: 'Label for the button to open bluetooth settings on the onboarding screen');

String onboardingDoneButtonLabel() => Intl.message("Done", name: 'onboardingDoneButtonLabel', desc: 'Label for the button to close the onboarding screen');

String onboardingCompletedTitle() => Intl.message("Happy Wagging!", name: 'onboardingCompletedTitle', desc: 'Title of the final page of the onboarding screen');

String doubleBackToClose() => Intl.message("Press again to exit ", name: 'doubleBackToClose', desc: 'Snackbar message which appears when the back button is pressed at the main screen');

String noLongerSupported() => Intl.message("This gear is no longer supported. Some app features may not work", name: 'noLongerSupported', desc: 'Warning message which appears for unsupported gear on the manage gear page');

String mandatoryOtaRequired() => Intl.message("A firmware update is required for this app to support your gear", name: 'mandatoryOtaRequired', desc: 'Warning message which appears for gear which have old firmware on the manage gear page');

String actionsFavoriteTip() => Intl.message("Long press an action to favorite", name: 'actionsFavoriteTip', desc: 'tip message which appears when no actions are favorited on the actions page');

String moreSourceCode() => Intl.message("Source Code", name: 'moreSourceCode', desc: 'Label for the github and dev mode button on the more tab');

String audioActionCategory() => Intl.message("Sound Effects", name: 'audioActionCategory', desc: 'Label for sound files');

String audioEditDescription() => Intl.message("Manage custom sound effects", name: 'audioEditDescription', desc: 'Label for sound files');

String audioEdit() => Intl.message("Rename Sound Effect", name: 'audioEdit', desc: 'Label for sound files');

String audioDelete() => Intl.message("Delete Sound Effect", name: 'audioDelete', desc: 'Label for sound files');

String audioDeleteDescription() => Intl.message("Are you sure you want to delete this sound effect?", name: 'audioDeleteDescription', desc: 'Label for the body of the delete confirmation dialog');

String audioAdd() => Intl.message("Add Sound Effect", name: 'audioAdd', desc: 'Label for sound files');

String audioTipCard() => Intl.message("You can add custom sounds that appear on the Actions tab and can be used with Triggers", name: 'audioTipCard', desc: 'Tutorial card for the audio page');

String scanDemoGear() => Intl.message("Fake Gear", name: 'scanDemoGear', desc: 'Label for the expansion tile to show the demo gear options on the scan for new devices page');

String scanAddDemoGear() => Intl.message("Add Fake Gear", name: 'scanAddDemoGear', desc: 'Label for the dropdown to select a demo gear to add on the scan for new devices page');

String scanRemoveDemoGear() => Intl.message("Remove all fake gear", name: 'scanRemoveDemoGear', desc: 'Label for the button to remove all demo gear on the scan for new devices page');

String scanDemoGearTip() => Intl.message("Want to try out the app but are waiting for your gear to arrive? Add a fake gear. This lets you experience the app as if you had your gear, or if you want to try out gear you currently do not own. This enables a new section on the 'Scan For New Gear' page.",
    name: 'scanDemoGearTip', desc: 'Tip Card description for the  demo gear on the scan for new devices page');

String triggerActionSelectorTutorialLabel() => Intl.message("Select as many actions as you want. An action will be randomly selected that is compatible with connected gear. GlowTip and Sound actions will trigger alongside Move actions. Don't forget to save.",
    name: 'triggerActionSelectorTutorialLabel', desc: 'Label for the tutorial card on the Action selector for triggers');

String featureLimitedOtaRequiredLabel() => Intl.message("Please update your gear to use this feature.", name: 'featureLimitedOtaRequiredLabel', desc: 'Label for the warning card when a feature requires a firmware update');

String joystickWarning() => Intl.message("The Joystick feature is experimental. Use at your own risk.", name: 'joystickWarning', desc: 'Label for the warning tutorial card on the joystick page');
