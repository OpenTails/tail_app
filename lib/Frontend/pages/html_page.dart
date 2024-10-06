import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../constants.dart';
import '../utils.dart';

part 'html_page.freezed.dart';

@freezed
class HtmlPageInfo with _$HtmlPageInfo {
  const factory HtmlPageInfo({
    required String url,
    required String title,
  }) = _HtmlPageInfo;
}

class HtmlPage extends StatefulWidget {
  const HtmlPage({required this.htmlPageInfo, super.key});

  @override
  State<StatefulWidget> createState() => _HtmlPageState();
  final HtmlPageInfo htmlPageInfo;
}

class _HtmlPageState extends State<HtmlPage> {
  String body = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.htmlPageInfo.title),
      ),
      body: AnimatedCrossFade(
        alignment: Alignment.center,
        firstChild: const Center(
          child: CircularProgressIndicator(),
        ),
        secondChild: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: HtmlWidget(
            body,
            renderMode: RenderMode.listView,
            factoryBuilder: MyWidgetFactory.new,
            onTapUrl: (p0) async {
              String url = '';
              if (!p0.endsWith('.pdf')) {
                url = p0 + getOutboundUtm();
              }
              if (url.startsWith('/doku.php')) {
                url = 'https://docs.thetailcompany.com$p0';
              }
              return launchUrlString(url);
            },
          ),
        ),
        crossFadeState: body.isNotEmpty ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: animationTransitionDuration,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    unawaited(getContent());
  }

  Future<void> getContent() async {
    Dio dio = await initDio();
    Response<String> pageContentResponse = await dio.get(widget.htmlPageInfo.url);
    if (pageContentResponse.statusCode! < 400 && mounted) {
      setState(() {
        body = pageContentResponse.data!;
      });
    }
  }
}

class MyWidgetFactory extends WidgetFactory {
  @override
  Widget? buildImageWidget(BuildTree tree, ImageSource src) {
    return LoadImage(url: src.url);
  }
}

class LoadImage extends StatefulWidget {
  final String url;

  const LoadImage({required this.url, super.key});

  @override
  State<StatefulWidget> createState() => _LoadImageState();
}

class _LoadImageState extends State<LoadImage> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: loadImage(),
      builder: (context, snapshot) {
        return AnimatedSwitcher(
          duration: animationTransitionDuration,
          child: Builder(
            builder: (context) {
              if (snapshot.hasData) {
                return snapshot.data!;
              } else {
                return const CircularProgressIndicator();
              }
            },
          ),
        );
      },
    );
  }

  Future<Widget> loadImage() async {
    Dio dio = await initDio();
    Response<List<int>> response = await dio.get(
      widget.url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );
    if (response.statusCode! < 400 && mounted) {
      return Image.memory(
        Uint8List.fromList(response.data!),
        fit: BoxFit.fill,
      );
    }
    return Container();
  }
}
