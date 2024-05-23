import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

class MarkdownInfo {
  final String content;
  final String title;

  const MarkdownInfo({required this.content, required this.title});
}

class MarkdownViewer extends StatelessWidget {
  const MarkdownViewer({super.key, required this.markdownInfo});

  final MarkdownInfo markdownInfo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(markdownInfo.title),
      ),
      body: Markdown(
        data: markdownInfo.content,
        extensionSet: md.ExtensionSet(
          md.ExtensionSet.gitHubFlavored.blockSyntaxes,
          <md.InlineSyntax>[md.EmojiSyntax(), ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes],
        ),
        onTapLink: (linkText, linkUrl, linkTitle) async => await launchUrl(Uri.parse(linkUrl!)),
      ),
    );
  }
}
