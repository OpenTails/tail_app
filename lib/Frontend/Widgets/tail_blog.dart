import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:url_launcher/url_launcher.dart';
// Used as MediaDetails isn't exported
// ignore: implementation_imports
import 'package:wordpress_client/src/responses/properties/media_details.dart';
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
      firstChild: feedState == FeedState.loading
          ? const LinearProgressIndicator()
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
    getFeed();
  }

  Future<void> getFeed() async {
    if (results.isEmpty) {
      if (!await tailBlogConnectivityCheck()) {
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
              feedType: FeedType.blog,
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
    required FeedType feedType,
    final int? imageId,
    final String? imageUrl,
  }) = _FeedItem;

  @override
  int compareTo(FeedItem other) {
    return other.publishDate.compareTo(publishDate);
  }
}

enum FeedState { loading, loaded, error, noInternet }

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
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        if (widget.feedItem.imageUrl != null) {
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
    );
  }
}

@Riverpod()
Future<Widget> getBlogImage(Ref ref, String url) async {
  if (!await tailBlogConnectivityCheck()) {
    return Container();
  }
  Dio dio = await initDio();

  Response<List<int>> response = await dio.get(
    url,
    options: cacheOptions
        .copyWith(
          policy: CachePolicy.forceCache,
        )
        .toOptions()
        .copyWith(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
  );

  if (response.statusCode! < 400) {
    Uint8List data = Uint8List.fromList(response.data!);
    return SizedBox.expand(
      child: FittedBox(
        alignment: Alignment.center,
        // TRY THIS: Try changing the fit types to see how they change the way
        // the placeholder fits into the container.
        fit: BoxFit.cover,
        child: Image.memory(
          data,
          width: 300,
        ),
      ),
    );
  }
  return Container();
}

Future<bool> tailBlogConnectivityCheck() async {
  final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult.contains(ConnectivityResult.none)) {
    return false;
  }
  if (HiveProxy.getOrDefault(settings, tailBlogWifiOnly, defaultValue: tailBlogWifiOnlyDefault) && {ConnectivityResult.wifi, ConnectivityResult.ethernet}.intersection(connectivityResult.toSet()).isEmpty) {
    return false;
  }
  return true;
}
