import 'dart:io';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wordpress_client/wordpress_client.dart';

final _wpLogger = Logger('Main');

class TailBlog extends StatefulWidget {
  const TailBlog({super.key, required this.controller});

  final ScrollController controller;

  @override
  State<TailBlog> createState() => _TailBlogState();
}

List<Post> _wordpressPosts = [];

class _TailBlogState extends State<TailBlog> {
  FeedState feedState = FeedState.loading;
  List<FeedItem> results = [];
  final WordpressClient client = getWordpressClient();

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      alignment: Alignment.center,
      firstChild: feedState == FeedState.loading ? const LinearProgressIndicator() : Container(),
      secondChild: ListView.builder(
        itemExtent: 300,
        controller: widget.controller,
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
                  child: InkWell(
                    onTap: () async {
                      await launchUrl(Uri.parse("${feedItem.url}?utm_source=Tail_App'"));
                    },
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: <Widget>[
                        if (feedItem.imageId != null) ...[
                          FutureBuilder(
                            future: getImage(feedItem, context),
                            builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                              return AnimatedOpacity(
                                duration: animationTransitionDuration,
                                opacity: snapshot.hasData ? 1 : 0,
                                child: snapshot.hasData ? snapshot.data! : Container(),
                              );
                            },
                          )
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
    if (_wordpressPosts.isEmpty) {
      try {
        // Slug, Sticky, and Author are not used
        final ListPostRequest request = ListPostRequest(
          page: 1, perPage: 10, order: Order.desc, queryParameters: {'_fields': 'id,title,link,featured_media_src_url,featured_media,sticky,slug,author,date'},
          //context: RequestContext.embed,
        );
        final WordpressResponse<List<Post>> wordpressPostResponse = await client.posts.list(request);
        List<Post>? data = wordpressPostResponse.dataOrNull();
        if (data != null) {
          _wordpressPosts = data;
          // Store the latest post id for checking for new posts
          SentryHive.box(notificationBox).put(latestPost, data.first.id);
        }
      } catch (e, s) {
        setState(() {
          feedState = FeedState.error;
        });
        _wpLogger.warning('Error when getting blog posts: $e', e, s);
      }
    }

    if (_wordpressPosts.isNotEmpty) {
      for (Post post in _wordpressPosts) {
        results.add(FeedItem(
          title: post.title!.parsedText,
          publishDate: post.date!,
          url: post.link,
          feedType: FeedType.blog,
          imageId: post.featuredMedia,
          imageUrl: post.featuredImageUrl,
        ));
      }
    }
    if (results.isNotEmpty && context.mounted) {
      setState(() {
        feedState = FeedState.loaded;
      });
    } else {
      setState(() {
        feedState = FeedState.error;
      });
    }
  }

  Future<Widget> getImage(FeedItem item, BuildContext context) async {
    String? mediaUrl;
    if (item.imageId != null) {
      String filePath = '${(await getTemporaryDirectory()).path}/media/${item.imageId}';

      File file = File(filePath);
      if (!await file.exists()) {
        // Get image url from wordpress api
        if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
          mediaUrl = item.imageUrl;
        } else {
          final RetrieveMediaRequest retrieveMediaRequest = RetrieveMediaRequest(id: item.imageId!);
          WordpressResponse<Media> retrieveMediaResponse = await client.media.retrieve(retrieveMediaRequest);
          if (retrieveMediaResponse.dataOrNull() != null) {
            Media mediaInfo = retrieveMediaResponse.dataOrNull()!;
            mediaUrl = mediaInfo.mediaDetails!.sizes!['full']!.sourceUrl!;
          }
        }

        if (mediaUrl != null) {
          // download the image
          await initDio().download(mediaUrl, filePath);
        }
      }
      if (await file.exists()) {
        if (context.mounted) {
          return Image.file(
            file,
            alignment: Alignment.bottomCenter,
            width: MediaQuery.of(context).size.width,
            fit: BoxFit.cover,
            height: 300,
          );
        }
      }
    }
    return Container();
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
