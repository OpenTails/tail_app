import 'package:collection/collection.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
