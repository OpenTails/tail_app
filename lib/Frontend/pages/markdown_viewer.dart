import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class MarkdownInfo {
  final String content;
  final String title;

  MarkdownInfo({required this.content, required this.title});
}

class MarkdownViewer extends StatefulWidget {
  const MarkdownViewer({super.key, required this.markdownInfo});

  final MarkdownInfo markdownInfo;

  @override
  _MarkdownViewerState createState() => _MarkdownViewerState();
}

class _MarkdownViewerState extends State<MarkdownViewer> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.markdownInfo.title),
      ),
      body: Markdown(
        data: widget.markdownInfo.content,
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          <md.InlineSyntax>[md.EmojiSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
        ),
        onTapLink: (linkText, linkUrl, linkTitle) async => await launchUrl(Uri.parse(linkUrl!)),
      ),
    );
  }
}
