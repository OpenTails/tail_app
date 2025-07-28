import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class TailBlogImage extends StatelessWidget {
  const TailBlogImage({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        alignment: Alignment.center,
        fit: BoxFit.cover,
        child: CachedNetworkImage(
          height: 300,
          imageUrl: url,
          progressIndicatorBuilder: (context, url, downloadProgress) => SizedBox.square(
            dimension: 40,
            child: CircularProgressIndicator(
              value: downloadProgress.progress,
            ),
          ),
          errorWidget: (context, url, error) => Icon(Icons.error),
        ),
      ),
    );
  }
}
