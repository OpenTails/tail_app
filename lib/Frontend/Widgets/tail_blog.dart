import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Frontend/Widgets/tail_blog_image.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_company_wp_proxy/tail_company_wp_proxy.dart';

import '../utils.dart';

final _wpLogger = Logger('TailBlog');

class TailBlog extends StatefulWidget {
  const TailBlog({super.key});

  @override
  State<TailBlog> createState() => _TailBlogState();
}

List<BlogPost> results = [];

class _TailBlogState extends State<TailBlog> {
  FeedState feedState = FeedState.loading;

  @override
  Widget build(BuildContext context) {
    switch (feedState) {
      case FeedState.loading:
        return Center(child: CircularProgressIndicator());
      case FeedState.noInternet:
      case FeedState.error:
        return const Center(
          child: Opacity(
            opacity: 0.5,
            child: Icon(
              Symbols.signal_cellular_connected_no_internet_0_bar,
              size: 150,
            ),
          ),
        );
      case FeedState.loaded:
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          shrinkWrap: true,
          itemCount: results.length,
          itemBuilder: (BuildContext context, int index) {
            BlogPost feedItem = results[index];
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 250,
                    child: Semantics(
                      label: 'A button to view the blog post: ${feedItem.name}',
                      child: InkWell(
                        onTap: () async {
                          await launchExternalUrl(
                            url: feedItem.url,
                            analyticsLabel: "Tail Blog Post",
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: <Widget>[
                            if (feedItem.thumbnail != null) ...[
                              SizedBox.expand(
                                child: TailBlogImage(
                                  url: feedItem.thumbnail ?? "",
                                ),
                              ),
                            ],
                            Card(
                              clipBehavior: Clip.antiAlias,
                              margin: EdgeInsets.zero,
                              elevation: 2,
                              child: ListTile(
                                //leading: Icon(feedItem.feedType.icon),
                                title: Text(convertToUwU(feedItem.name)),
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
    if (results.isEmpty) {
      if (await isLimitedDataEnvironment() ||
          !(await getDynamicConfigInfo()).featureFlags.enableTailBlogPosts) {
        setState(() {
          feedState = FeedState.noInternet;
        });
        return;
      }
      try {
        TailCompanyWpProxyClient tailCompanyWpProxyClient =
            TailCompanyWpProxyClient(
              dio: await initDio(),
              baseUrl: (await getDynamicConfigInfo()).urls.tailProxyBaseUrl,
            );
        List<BlogPost> posts = await tailCompanyWpProxyClient.getBlogPosts();
        results = posts;
        //filter out posts that are missing a thumbnail
        results = results
            .where((element) => element.thumbnail != null)
            .toList();
        // Slug, Sticky, and Author are not used
      } catch (e, s) {
        setState(() {
          feedState = FeedState.error;
        });
        _wpLogger.warning('Error when getting blog posts: $e', e, s);
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
}

enum FeedState { loading, loaded, error, noInternet }
