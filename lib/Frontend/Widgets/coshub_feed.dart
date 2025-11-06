import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Backend/firebase.dart';
import 'package:tail_app/Frontend/Widgets/tail_blog.dart';
import 'package:tail_app/Frontend/Widgets/tail_blog_image.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/utils.dart';

class CoshubFeed extends ConsumerStatefulWidget {
  const CoshubFeed({super.key});

  @override
  ConsumerState<CoshubFeed> createState() => _CoshubFeedState();
}

List<CosHubPost> results = [];

class _CoshubFeedState extends ConsumerState<CoshubFeed> {
  FeedState feedState = FeedState.loading;

  @override
  Widget build(BuildContext context) {

    switch (feedState) {
      case FeedState.loading:
        return Center(child: CircularProgressIndicator());
      case FeedState.noInternet:
      case FeedState.error:
        return const Center(child: Opacity(opacity: 0.5, child: Icon(Icons.signal_cellular_connected_no_internet_0_bar, size: 150)));
      case FeedState.loaded:
       return ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: results.length,
          itemBuilder: (BuildContext context, int index) {
            CosHubPost post = results[index];
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 250,
                    child: Semantics(
                      label: 'A button to view the CosHub post by: ${post.username}',
                      child: InkWell(
                        onTap: () async {
                          await launchExternalUrl(url: post.url, analyticsLabel: "CosHub Post");
                        },
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: <Widget>[
                            if (post.thumbnailUrl != "") ...[
                              SizedBox.expand(
                                child: TailBlogImage(
                                  url: post.thumbnailUrl,
                                ),
                              ),
                            ],
                            Card(
                              clipBehavior: Clip.antiAlias,
                              margin: EdgeInsets.zero,
                              elevation: 2,
                              child: ListTile(
                                //leading: Icon(feedItem.feedType.icon),
                                title: Text(convertToUwU(post.username)), subtitle: post.character != null ? Text(convertToUwU(post.character!)) : null,
                                leading: post.profileThumbnailUrl != null
                                    ? ClipOval(
                                  child: SizedBox.fromSize(
                                    size: Size.fromRadius(24),
                                    child: TailBlogImage(
                                      url: post.profileThumbnailUrl!,
                                    ),
                                  ),
                                )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
    }


  }

  @override
  void dispose() {
    super.dispose();
    //client.dispose();
  }

  @override
  void initState() {
    super.initState();
    getFeed();
  }

  Future<void> getFeed() async {
    if (results.isNotEmpty) {
      setState(() {
        feedState = FeedState.loaded;
      });
      return;
    }
    if (await isLimitedDataEnvironment() || !(await getDynamicConfigInfo()).featureFlags.enableCoshubPosts) {
      setState(() {
        feedState = FeedState.noInternet;
      });
      return;
    }
    List<CosHubPost> cosHubPosts = await ref.read(getCosHubPostsProvider.future);
    setState(() {
      results = cosHubPosts;
      feedState = FeedState.loaded;
    });
  }
}
