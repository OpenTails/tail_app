import 'dart:async';

import 'package:collection/collection.dart';
import 'package:firedart/firedart.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app_shared/tail_app_shared.dart';

bool _didInit = false;

void init() {
  if (_didInit) {
    return;
  }
  Firestore.initialize("coshub-df5cf");
  _didInit = true;
}

Timer? requestCooldown;
bool shouldRefresh = true;
CoshubResponse? cachedResponse;

//Quickly return the known current response, but update after a cooldown
Future<CoshubResponse> getCoshubResponse() async {
  if (cachedResponse != null) {
    updateCoshubResponse();
    return cachedResponse!;
  } else {
    return await updateCoshubResponse();
  }
}

Future<CoshubResponse> updateCoshubResponse() async {
  if (!shouldRefresh && cachedResponse != null) {
    return cachedResponse!;
  }
  List<CosHubPost> mappedPosts = await getCoshubPosts();
  if (mappedPosts.isEmpty && cachedResponse != null) {
    return cachedResponse!;
  }
  cachedResponse = CoshubResponse(
    timestamp: DateTime.now(),
    posts: mappedPosts,
  );
  requestCooldown = Timer(Duration(minutes: 10), () {
    shouldRefresh = true;
    requestCooldown?.cancel();
    requestCooldown = null;
  });
  return cachedResponse!;
}

Future<List<CosHubPost>> getCoshubPosts() async {
  init();
  var appConstants = Firestore.instance.collection("appConstants");
  var featuredCosplayersUserIdsQuery = await appConstants
      .document("featured_cosplayers")
      .get();
  List<dynamic> featuredCosplayersUserIds =
      featuredCosplayersUserIdsQuery.map["user"] as List<dynamic>;
  var usersQuery = await Firestore.instance
      .collection("users")
      .where("id", whereIn: featuredCosplayersUserIds)
      .get();
  List<CosHubPost> mappedPosts = [];

  final String cosHubUrl = (await getDynamicConfigInfo()).urls.coshubUrl;

  for (String featuredCosplayersUserId in featuredCosplayersUserIds) {
    var postsQuery = await Firestore.instance
        .collection("posts")
        .where("userId", isEqualTo: featuredCosplayersUserId)
        .orderBy("createdAt", descending: true)
        .limit(5)
        .get();
    mappedPosts.addAll(
      postsQuery
          .map((e) => e.map)
          .where((element) {
            List<dynamic>? postImageUrls = element["postImageUrls"];
            return postImageUrls != null && postImageUrls.isNotEmpty;
          })
          .map((postData) {
            Map<String, dynamic> userData = usersQuery
                .firstWhere(
                  (element) => element.map["id"] == postData["userId"],
                )
                .map;
            CosHubPost cosHubPost = CosHubPost(
              id: postData["id"],
              url: cosHubUrl,
              thumbnailUrl: postData["postImageUrls"][0],
              profileThumbnailUrl: userData["profilePicture"],
              username: userData["username"],
              character: postData["character"],
              timestamp: postData['createdAt'],
            );
            return cosHubPost;
          })
          .sortedBy((element) => element.timestamp)
          .toList(),
    );
  }
  return mappedPosts;
}
