import 'dart:io';

import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../constants.dart';
import '../firebase_options.dart';
import 'logging_wrappers.dart';

//TODO: Add setting
//TODO: Add onboarding
//TODO: reset ID when disabled
Future<void> configurePushNotifications() async {
  // Required before doing anything with firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //Disable firebase and clear ID
  if (!HiveProxy.getOrDefault(settings, marketingNotificationsEnabled, defaultValue: marketingNotificationsEnabledDefault) ||
      HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) != hasCompletedOnboardingVersionToAgree) {
    await FirebaseInstallations.instance.delete();
    FirebaseMessaging.instance.setAutoInitEnabled(false);
    return;
  }

  final firebaseMessaging = FirebaseMessaging.instance;
  // configure auto-init if notifications are enabled or not
  firebaseMessaging.setAutoInitEnabled(true);
  NotificationSettings notificationSettings = await firebaseMessaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<String?> getFirebaseToken() async {
  final firebaseMessaging = FirebaseMessaging.instance;
  final token = Platform.isIOS ? await firebaseMessaging.getAPNSToken() : await firebaseMessaging.getToken();
  return token;
}
