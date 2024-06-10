import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';

Future<void> initNotifications() async {
  AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
      'resource://drawable/res_app_icon',
      [
        NotificationChannel(
          channelKey: blogChannelKey,
          channelName: 'Tail Blog',
          channelDescription: 'New Posts in the Tail Blog',
        )
      ],
      debug: true);
}

class NotificationController {
  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(ReceivedNotification receivedNotification) async {
    // Your code goes here
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    // Your code goes here
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    // Your code goes here
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    // New Tail Blog Post
    if (receivedAction.channelKey == blogChannelKey && receivedAction.payload != null && receivedAction.payload!.containsKey('url')) {
      await launchUrl(Uri.parse("${receivedAction.payload!['url']}${getOutboundUtm()}"));
    }
    // Navigate into pages, avoiding to open the notification details page over another details page already opened
    //MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/notification-page', (route) => (route.settings.name != '/notification-page') || route.isFirst, arguments: receivedAction);
  }
}
