import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_corner_banner/flutter_corner_banner.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logging/logging.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:tail_app/Backend/analytics.dart';
import 'package:tail_app/Backend/dynamic_config.dart';
import 'package:tail_app/Frontend/Widgets/tail_blog.dart';
import 'package:tail_app/Frontend/Widgets/tail_blog_image.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';
import 'package:tail_app/Frontend/utils.dart';

part 'store_feed.freezed.dart';
part 'store_feed.g.dart';

@freezed
abstract class StoreProduct with _$StoreProduct {
  const factory StoreProduct({
    required int id,
    required String name,
    required bool on_sale,
    required bool is_in_stock,
    required String permalink,
    required List<StoreProductImage> images,
  }) = _StoreProduct;

  factory StoreProduct.fromJson(Map<String, dynamic> json) =>
      _$StoreProductFromJson(json);
}

@freezed
abstract class StoreProductImage with _$StoreProductImage {
  const factory StoreProductImage({
    required int id,
    required String src,
    required String thumbnail,
    required String alt,
  }) = _StoreProductImage;

  factory StoreProductImage.fromJson(Map<String, dynamic> json) =>
      _$StoreProductImageFromJson(json);
}

final _logger = Logger('TailBlog');

class StoreProductList extends StatefulWidget {
  const StoreProductList({super.key});

  @override
  State<StoreProductList> createState() => _StoreProductListState();
}

List<StoreProduct> results = [];

class _StoreProductListState extends State<StoreProductList> {
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
            StoreProduct feedItem = results[index];
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    width: 250,
                    child: Semantics(
                      label:
                          'A button to view the store listing: ${feedItem.name}',
                      child: InkWell(
                        onTap: () async {
                          await launchExternalUrl(
                            url: feedItem.permalink,
                            analyticsLabel: "Store Product",
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: <Widget>[
                            if (feedItem.images.isNotEmpty) ...[
                              SizedBox.expand(
                                child: CornerBanner(
                                  bannerText: "Sale",
                                  bannerColor: Colors.red,
                                  bannerSize: 60,
                                  showBanner: feedItem.on_sale,
                                  bannerTextStyle: TextTheme.of(
                                    context,
                                  ).labelLarge,
                                  child: TailBlogImage(
                                    url: feedItem.images.first.thumbnail,
                                  ),
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
          !(await getDynamicConfigInfo()).featureFlags.enableStoreProducts) {
        setState(() {
          feedState = FeedState.noInternet;
        });
        return;
      }
      List<StoreProduct> storeProducts = [];
      try {
        Dio dio = await initDio();
        Response<dynamic> response = await dio.get(
          "https://thetailcompany.com/wp-json/wc/store/v1/products?tag=select&per_page=100",
        );

        final List<dynamic> raw = response.data as List<dynamic>;
        storeProducts = raw
            .map((e) => StoreProduct.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e, s) {
        setState(() {
          feedState = FeedState.error;
        });
        _logger.warning('Error when getting store products: $e', e, s);
      }
      if (storeProducts.isNotEmpty) {
        results = storeProducts;

        //filter out posts that are missing a thumbnail
        results = results
            .where((element) => element.images.isNotEmpty)
            .toList();
        //show products on sale first, then the rest in random order
        final onSale = results.where((e) => e.on_sale).toList()..shuffle();
        final notOnSale = results.where((e) => !e.on_sale).toList()..shuffle();
        results = [...onSale, ...notOnSale];
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
