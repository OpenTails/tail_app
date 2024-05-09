import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/firebase_options.dart';

final fireLogger = Logger('Firebase');

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  fireLogger.info("Handling a background message: ${message.messageId}");
}

Future<void> initFirebase() async {
  try {
    fireLogger.info("Begin init Firebase");
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    FirebaseMessaging messaging = FirebaseMessaging.instance;
    messaging.app.setAutomaticDataCollectionEnabled(false);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await messaging.subscribeToTopic("newsletter");
    final notificationSettings = await messaging.requestPermission(
      provisional: true,
      sound: false,
    );
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: false,
    );
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      fireLogger.info('Got a message whilst in the foreground!');
      fireLogger.info('Message data: ${message.data}');

      if (message.notification != null) {
        fireLogger.info(
            'Message also contained a notification: ${message.notification}');
        const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
          'newsletter',
          'Newsletter',
          channelDescription: 'Notifications from the Tail Company Newsletter',
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          enableLights: false,
        );
        const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);
        await flutterLocalNotificationsPlugin?.show(
          message.notification.hashCode,
          message.notification?.title,
          message.notification?.body,
          notificationDetails,
        );
      }
    });
  }
  catch(e,s) {
    fireLogger.shout('error setting up firebase',e,s);
  }
}

Future<String?> getFirebaseToken() async {
  return await (FirebaseMessaging.instance).getToken();
}

FlutterLocalNotificationsPlugin? flutterLocalNotificationsPlugin;

Future<void> initNotificationPlugin() async {
  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  // initialise the plugin. app_icon needs to be a added as a drawable resource to the Android head project
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings("@mipmap/ic_launcher");
  const DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
          defaultPresentSound: false, requestSoundPermission: false);
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
  );
  await flutterLocalNotificationsPlugin?.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
  );
}

//Foreground
void onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (notificationResponse.payload != null) {
    fireLogger.info('notification payload: $payload');
  }
}

//background
@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
    NotificationResponse notificationResponse) {
  final String? payload = notificationResponse.payload;
  if (notificationResponse.payload != null) {
    fireLogger.info('notification payload: $payload');
  }
}
