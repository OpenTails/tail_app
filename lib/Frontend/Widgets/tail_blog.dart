import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wordpress_client/wordpress_client.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../utils.dart';

part 'tail_blog.freezed.dart';
part 'tail_blog.g.dart';

final _wpLogger = Logger('Main');

class TailBlog extends StatefulWidget {
  const TailBlog({required this.controller, super.key});

  final ScrollController controller;

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
      firstChild: feedState == FeedState.loading ? const LinearProgressIndicator() : Container(),
      secondChild: GridView.builder(
        controller: widget.controller,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 500, mainAxisExtent: 300),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: results.length,
        itemBuilder: (BuildContext context, int index) {
          FeedItem feedItem = results[index];
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 300,
                  child: Semantics(
                    label: 'A button to view the blog post: ${feedItem.title}',
                    child: InkWell(
                      onTap: () async {
                        await launchUrl(Uri.parse("${feedItem.url}${getOutboundUtm()}"));
                      },
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: <Widget>[
                          if (feedItem.imageId != null) ...[
                            TailBlogImage(
                              feedItem: feedItem,
                            ),
                          ],
                          Card(
                            clipBehavior: Clip.antiAlias,
                            margin: EdgeInsets.zero,
                            elevation: 2,
                            child: ListTile(
                              //leading: Icon(feedItem.feedType.icon),
                              trailing: const Icon(Icons.open_in_browser),
                              title: Text(feedItem.title),
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
    unawaited(getFeed());
  }

  Future<void> getFeed() async {
    if (results.isEmpty) {
      List<Post> wordpressPosts = [];
      try {
        // Slug, Sticky, and Author are not used
        final ListPostRequest request = ListPostRequest(
          page: 1, perPage: 10, order: Order.desc, queryParameters: {'_fields': 'id,title,link,featured_media_src_url,featured_media,sticky,slug,author,date'},
          //context: RequestContext.embed,
        );
        client ??= await getWordpressClient();
        final WordpressResponse<List<Post>> wordpressPostResponse = await client!.posts.list(request);
        List<Post>? data = wordpressPostResponse.dataOrNull();
        if (data != null) {
          wordpressPosts = data;
          // Store the latest post id for checking for new posts
          HiveProxy.put(notificationBox, latestPost, data.first.id);
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
              feedType: FeedType.blog,
              imageId: post.featuredMedia,
              imageUrl: post.featuredImageUrl,
            ),
          );
        }
      }
    }
    if (results.isNotEmpty && context.mounted) {
      setState(() {
        feedState = FeedState.loaded;
      });
    } else if (context.mounted) {
      setState(() {
        feedState = FeedState.error;
      });
    }
  }
}

@freezed
class FeedItem with _$FeedItem implements Comparable<FeedItem> {
  //Image ID is used as the wordpress image ID and the unique id to identify the image in cache
  const FeedItem._();

  @Implements<Comparable<FeedItem>>()
  const factory FeedItem({
    required String url,
    required String title,
    required DateTime publishDate,
    required FeedType feedType,
    final int? imageId,
    final String? imageUrl,
  }) = _FeedItem;

  @override
  int compareTo(FeedItem other) {
    return other.publishDate.compareTo(publishDate);
  }
}

enum FeedState {
  loading,
  loaded,
  error,
}

enum FeedType {
  wiki,
  blog,
}

extension FeedTypeExtension on FeedType {
  IconData get icon {
    switch (this) {
      case FeedType.blog:
        return Icons.newspaper;
      case FeedType.wiki:
        return Icons.notes;
    }
  }
}

class TailBlogImage extends ConsumerStatefulWidget {
  const TailBlogImage({required this.feedItem, super.key});

  final FeedItem feedItem;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _TailBlogImageState();
}

class _TailBlogImageState extends ConsumerState<TailBlogImage> {
  bool isVisible = false;

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ValueKey(widget.feedItem),
      onVisibilityChanged: (VisibilityInfo info) {
        if (context.mounted) {
          setState(() {
            isVisible = info.visibleFraction > 0;
          });
        }
      },
      child: Builder(
        builder: (context) {
          if (isVisible && widget.feedItem.imageUrl != null) {
            var snapshot = ref.watch(getBlogImageProvider(widget.feedItem.imageUrl!));
            return AnimatedOpacity(
              duration: animationTransitionDuration,
              opacity: snapshot.hasValue ? 1 : 0,
              child: snapshot.hasValue ? snapshot.value! : const CircularProgressIndicator(),
            );
          } else {
            return Container();
          }
        },
      ),
    );
  }
}

@Riverpod(keepAlive: true)
Future<Widget> getBlogImage(GetBlogImageRef ref, String url) async {
  Dio dio = await initDio();
  Response<List<int>> response = await dio.get(
    url,
    options: Options(
      responseType: ResponseType.bytes,
      followRedirects: true,
    ),
  );

  if (response.statusCode! < 400) {
    Uint8List data = Uint8List.fromList(response.data!);
    return Image.memory(
      data,
      alignment: Alignment.bottomCenter,
      fit: BoxFit.cover,
      height: 300,
      width: 500,
      cacheHeight: 300,
      cacheWidth: 500,
    );
  }
  return Container();
}
