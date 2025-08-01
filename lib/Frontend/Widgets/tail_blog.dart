import 'dart:async';

import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Frontend/Widgets/tail_blog_image.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
// Used as MediaDetails isn't exported
// ignore: implementation_imports
import 'package:wordpress_client/src/responses/properties/media_details.dart';
import 'package:wordpress_client/wordpress_client.dart';

import '../../constants.dart';
import '../utils.dart';

part 'tail_blog.freezed.dart';

final _wpLogger = Logger('Main');

class TailBlog extends StatefulWidget {
  const TailBlog({super.key});

  @override
  State<TailBlog> createState() => _TailBlogState();
}

List<FeedItem> results = [];

class _TailBlogState extends State<TailBlog> {
  FeedState feedState = FeedState.loading;

  WordpressClient? client;

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      alignment: Alignment.topCenter,
      firstChild: feedState == FeedState.loading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : [FeedState.noInternet, FeedState.error].contains(feedState)
              ? const Center(
                  child: Opacity(
                    opacity: 0.5,
                    child: Icon(
                      Icons.signal_cellular_connected_no_internet_0_bar,
                      size: 150,
                    ),
                  ),
                )
              : Container(),
      secondChild: ListView.builder(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: results.length,
        itemBuilder: (BuildContext context, int index) {
          FeedItem feedItem = results[index];
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 300,
                  child: Semantics(
                    label: 'A button to view the blog post: ${feedItem.title}',
                    child: InkWell(
                      onTap: () async {
                        await launchExternalUrl(url: feedItem.url, analyticsLabel: "Tail Blog Post");
                      },
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: <Widget>[
                          if (feedItem.imageId != null) ...[
                            SizedBox.expand(
                              child: TailBlogImage(
                                url: feedItem.imageUrl ?? "",
                              ),
                            ),
                          ],
                          Card(
                            clipBehavior: Clip.antiAlias,
                            margin: EdgeInsets.zero,
                            elevation: 2,
                            child: ListTile(
                              //leading: Icon(feedItem.feedType.icon),
                              title: Text(convertToUwU(feedItem.title)),
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
      ),
      crossFadeState: results.isNotEmpty ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: animationTransitionDuration,
    );
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
    if (results.isEmpty) {
      if (await isLimitedDataEnvironment() || !(await getDynamicConfigInfo()).featureFlags.enableTailBlogPosts) {
        setState(() {
          feedState = FeedState.noInternet;
        });
        return;
      }
      List<Post> wordpressPosts = [];
      try {
        // Slug, Sticky, and Author are not used
        final ListPostRequest request = ListPostRequest(
          page: 1,
          perPage: 10,
          order: Order.desc,
          queryParameters: {'_embed': 'true', '_fields': '_links.wp:featuredmedia,id,link,title,date,featured_media'},
          context: RequestContext.embed,
        );
        client ??= await getWordpressClient();
        final WordpressResponse<List<Post>> wordpressPostResponse = await client!.posts.list(request);
        List<Post>? data = wordpressPostResponse.dataOrNull();
        if (data != null) {
          wordpressPosts = data;
        }
      } catch (e, s) {
        setState(() {
          feedState = FeedState.error;
        });
        _wpLogger.warning('Error when getting blog posts: $e', e, s);
      }
      if (wordpressPosts.isNotEmpty) {
        for (Post post in wordpressPosts) {
          results.add(
            FeedItem(
              title: post.title!.parsedText,
              publishDate: post.date!,
              url: post.link,
              imageId: post.featuredMedia,
              imageUrl: await getImageURL(post),
            ),
          );
        }
      }
    }
    if (mounted && context.mounted) {
      setState(() {
        if (results.isNotEmpty) {
          feedState = FeedState.loaded;
        } else {
          feedState = FeedState.error;
        }
      });
    }
  }

  Future<String?> getImageURL(Post post) async {
    try {
      MediaDetails mediaDetails = MediaDetails.fromJson(post.self['_embedded']['wp:featuredmedia'][0]['media_details']);
      if (mediaDetails.sizes == null) {
        return null;
      }
      if (mediaDetails.sizes!.containsKey('medium')) {
        // matches the app blog image size
        return mediaDetails.sizes!['medium']!.sourceUrl;
      } else if (mediaDetails.sizes!.containsKey('thumbnail')) {
        // smaller fallback
        return mediaDetails.sizes!['thumbnail']!.sourceUrl;
      } else if (mediaDetails.sizes!.containsKey('full')) {
        // when all else fails
        return mediaDetails.sizes!['full']!.sourceUrl;
      }
    } catch (e) {
      _wpLogger.warning("Unable to load featured media for post ${post.title}. $e");
    }
    return null;
  }
}

@freezed
abstract class FeedItem with _$FeedItem implements Comparable<FeedItem> {
  //Image ID is used as the wordpress image ID and the unique id to identify the image in cache
  const FeedItem._();

  @Implements<Comparable<FeedItem>>()
  const factory FeedItem({
    required String url,
    required String title,
    required DateTime publishDate,
    final int? imageId,
    final String? imageUrl,
  }) = _FeedItem;

  @override
  int compareTo(FeedItem other) {
    return other.publishDate.compareTo(publishDate);
  }
}

enum FeedState { loading, loaded, error, noInternet }
