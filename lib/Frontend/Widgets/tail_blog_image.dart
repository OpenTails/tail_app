import 'package:cached_network_image_ce/cached_network_image.dart';
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
          height: 250,
          imageUrl: url,
          errorBuilder: (context, url, error) => Icon(Icons.error),
        ),
      ),
    );
  }
}
