import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';

part 'tail_blog_image.g.dart';

class TailBlogImage extends ConsumerStatefulWidget {
  const TailBlogImage({required this.url, super.key});

  final String url;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _TailBlogImageState();
}

class _TailBlogImageState extends ConsumerState<TailBlogImage> {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        if (widget.url != "") {
          var snapshot = ref.watch(getBlogImageProvider(widget.url));
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
  if (await isLimitedDataEnvironment()) {
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
