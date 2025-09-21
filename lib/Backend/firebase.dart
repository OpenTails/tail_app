import 'dart:io';

import 'package:collection/collection.dart';
import 'package:firebase_app_installations/firebase_app_installations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants.dart';
import 'logging_wrappers.dart';

part 'firebase.g.dart';
part 'firebase.freezed.dart';

@Riverpod(keepAlive: true)
Future<void> initCosHubFirebase(Ref ref) async {
  await Firebase.initializeApp(
    name: 'CosHub', // Give your second app a custom name
    options: CosHubFirebaseOptions.currentPlatform,
  );
}

@freezed
abstract class CosHubPost with _$CosHubPost {
  const factory CosHubPost({required String id, required String url, String? character, required String thumbnailUrl, String? profileThumbnailUrl, required String username, required DateTime timestamp}) = _CosHubPost;

  factory CosHubPost.fromJson(Map<String, dynamic> json) => _$CosHubPostFromJson(json);
}

@Riverpod()
Future<List<CosHubPost>> getCosHubPosts(Ref ref) async {
  await ref.read(initCosHubFirebaseProvider.future);
  FirebaseApp secondaryApp = Firebase.app("CosHub");
  FirebaseFirestore firestore = FirebaseFirestore.instanceFor(app: secondaryApp);
  final appConstants = firestore.collection("appConstants");
  DocumentSnapshot<Map<String, dynamic>> featuredCosplayersUserIdsQuery = await appConstants.doc("featured_cosplayers").get();
  List<dynamic> featuredCosplayersUserIds = featuredCosplayersUserIdsQuery.data()!["user"] as List<dynamic>;
  final QuerySnapshot<Map<String, dynamic>> usersQuery = await firestore.collection("users").where("id", whereIn: featuredCosplayersUserIds).get();

  List<CosHubPost> mappedPosts = [];

  final String cosHubUrl = (await getDynamicConfigInfo()).urls.coshubUrl;

  // We want to grab a few posts from each featured user
  for (String featuredCosplayersUserId in featuredCosplayersUserIds) {
    final QuerySnapshot<Map<String, dynamic>> postsQuery = await firestore
        .collection("posts")
        .where("userId", isEqualTo: featuredCosplayersUserId)
        .orderBy("createdAt", descending: true)
        .limit(5)
        .get();
    mappedPosts.addAll(
      postsQuery.docs
          .map((e) => e.data())
          .where((element) {
            List<dynamic>? postImageUrls = element["postImageUrls"];
            return postImageUrls != null && postImageUrls.isNotEmpty;
          })
          .map((postData) {
            Map<String, dynamic> userData = usersQuery.docs.firstWhere((element) => element.data()["id"] == postData["userId"]).data();
            CosHubPost cosHubPost = CosHubPost(
              id: postData["id"],
              url: cosHubUrl,
              thumbnailUrl: postData["postImageUrls"][0],
              profileThumbnailUrl: userData["profilePicture"],
              username: userData["username"],
              character: postData["character"],
              timestamp: (postData['createdAt'] as Timestamp).toDate()
            );
            return cosHubPost;
          })
          .sortedBy((element) => element.timestamp,).toList(),
    );
  }

  return mappedPosts;
}

//TODO: reset ID when disabled
bool didInitFirebase = false;
Future<void> configurePushNotifications() async {
  if (!didInitFirebase) {
    // Required before doing anything with firebase
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    didInitFirebase = true;
  }

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
