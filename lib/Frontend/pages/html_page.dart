import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../constants.dart';
import '../utils.dart';

class HtmlPageInfo {
  String url;
  String title;

  HtmlPageInfo({required this.url, required this.title});
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
            onTapUrl: (p0) async => launchUrlString('$p0$getOutboundUtm()'),
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
