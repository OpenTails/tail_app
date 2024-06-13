import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wordpress_client/wordpress_client.dart';

import '../../Backend/logging_wrappers.dart';
import '../../constants.dart';
import '../utils.dart';

final _wpLogger = Logger('Main');

class TailBlog extends StatefulWidget {
  const TailBlog({required this.controller, super.key});

  final ScrollController controller;

  @override
  State<TailBlog> createState() => _TailBlogState();
}

List<Post> _wordpressPosts = [];
List<FeedItem> results = [];
Map<int, Uint8List> images = {};

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
    if (_wordpressPosts.isEmpty) {
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
          _wordpressPosts = data;
          // Store the latest post id for checking for new posts
          HiveProxy.put(notificationBox, latestPost, data.first.id);
        }
      } catch (e, s) {
        setState(() {
          feedState = FeedState.error;
        });
        _wpLogger.warning('Error when getting blog posts: $e', e, s);
      }
      if (_wordpressPosts.isNotEmpty) {
        for (Post post in _wordpressPosts) {
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

class FeedItem implements Comparable<FeedItem> {
  String title;
  DateTime publishDate;
  String url;
  FeedType feedType;

  //Image ID is used as the wordpress image ID and the unique id to identify the image in cache
  int? imageId;
  String? imageUrl;

  FeedItem({required this.title, required this.publishDate, required this.url, required this.feedType, this.imageId, this.imageUrl});

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

class TailBlogImage extends StatefulWidget {
  const TailBlogImage({required this.feedItem, super.key});

  final FeedItem feedItem;

  @override
  State<StatefulWidget> createState() => _TailBlogImageState();
}

class _TailBlogImageState extends State<TailBlogImage> {
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
          if (isVisible || images.containsKey(widget.feedItem.imageId)) {
            return FutureBuilder(
              future: getImage(widget.feedItem, context),
              builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                return AnimatedOpacity(
                  duration: animationTransitionDuration,
                  opacity: snapshot.hasData ? 1 : 0,
                  child: snapshot.hasData ? snapshot.data! : const CircularProgressIndicator(),
                );
              },
            );
          } else {
            return Container();
          }
        },
      ),
    );
  }

  Future<Widget> getImage(FeedItem item, BuildContext context) async {
    String? mediaUrl;
    Widget? widget;
    if (item.imageId != null) {
      Uint8List? data;
      if (images.containsKey(item.imageId)) {
        data = images[item.imageId];
      }
      if (data == null) {
        // Get image url from wordpress api
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
          mediaUrl = item.imageUrl;
        } else {
          final RetrieveMediaRequest retrieveMediaRequest = RetrieveMediaRequest(id: item.imageId!);
          WordpressClient client = await getWordpressClient();
          WordpressResponse<Media> retrieveMediaResponse = await client!.media.retrieve(retrieveMediaRequest);
          if (retrieveMediaResponse.dataOrNull() != null) {
            Media mediaInfo = retrieveMediaResponse.dataOrNull()!;
            mediaUrl = mediaInfo.mediaDetails!.sizes!['full']!.sourceUrl!;
          }
        }
        if (mediaUrl != null) {
          // download the image
          Dio dio = await initDio();
          Response<List<int>> response = await dio.get(
            mediaUrl,
            options: Options(
              responseType: ResponseType.bytes,
              followRedirects: true,
            ),
          );
          if (response.statusCode! < 400) {
            data = Uint8List.fromList(response.data!);
            images[item.imageId!] = data;
          }
        }
      }

      if (data != null && context.mounted) {
        widget = Image.memory(
          data,
          alignment: Alignment.bottomCenter,
          width: MediaQuery.of(context).size.width,
          fit: BoxFit.cover,
          height: 300,
        );
      }
    }

    return widget ?? Container();
  }
}
