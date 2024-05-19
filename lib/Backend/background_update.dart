// [Android-only] This "Headless Task" is run when the Android app is terminated with `enableHeadless: true`
// Be sure to annotate your callback function to avoid issues in release mode on Flutter >= 3.3.0
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:logging/logging.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';
import 'package:wordpress_client/wordpress_client.dart';

final _backgroundLogger = Logger('BackgroundLogger');

Future<void> initBackgroundTasks() async {
  // Step 1:  Configure BackgroundFetch as usual.
  await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 1440,
        // 1 day
        startOnBoot: true,
        requiresBatteryNotLow: true,
        requiredNetworkType: NetworkType.UNMETERED,
        stopOnTerminate: false,
      ), (String taskId) async {
    // <-- Event callback.
    // This is the fetch-event callback.
    _backgroundLogger.info("[BackgroundFetch] taskId: $taskId");

    // Use a switch statement to route task-handling.
    switch (taskId) {
      case 'com.codel1417.tail_app.blog':
        checkForNewPosts();
        break;
      default:
        _backgroundLogger.info("Default fetch task");
    }
    // Finish, providing received taskId.
    BackgroundFetch.finish(taskId);
  }, (String taskId) async {
    // <-- Event timeout callback
    // This task has exceeded its allowed running-time.  You must stop what you're doing and immediately .finish(taskId)
    _backgroundLogger.info("[BackgroundFetch] TIMEOUT taskId: $taskId");
    BackgroundFetch.finish(taskId);
  });
  BackgroundFetch.scheduleTask(
    TaskConfig(
      taskId: "com.codel1417.tail_app.blog",
      delay: 5000, // <-- milliseconds
      periodic: true,
    ),
  );
}

Future<void> checkForNewPosts() async {
  if (!SentryHive.box(settings).get(allowNewsletterNotifications, defaultValue: allowNewsletterNotificationsDefault)) {
    return;
  }
  _backgroundLogger.info("Checking for new posts");
  try {
    final WordpressClient client = getWordpressClient();
    final ListPostRequest request = ListPostRequest(
      page: 1,
      perPage: 1,
      order: Order.desc,
      //context: RequestContext.embed,
    );
    final WordpressResponse<List<Post>> wordpressPostResponse = await client.posts.list(request);
    final List<Post>? data = wordpressPostResponse.dataOrNull();
    if (data != null) {
      final Post post = data.first;
      final int id = post.id;
      final int oldID = SentryHive.box(notificationBox).get(latestPost, defaultValue: defaultPostId);
      if (oldID < id) {
        _backgroundLogger.info("Found a new post");
        SentryHive.box(notificationBox).put(showAccurateBattery, id);
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: id,
            channelKey: blogChannelKey,
            actionType: ActionType.Default,
            roundedBigPicture: true,
            title: post.title!.rendered,
            bigPicture: post.featuredImageUrl,
            payload: {'url': post.link},
          ),
        );
      }
    }
  } catch (e, s) {
    _backgroundLogger.warning('Error getting new posts: $e', e, s);
  }
}
