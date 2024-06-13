import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

part 'markdown_viewer.freezed.dart';

@freezed
class MarkdownInfo with _$MarkdownInfo {
  const factory MarkdownInfo({
    required String content,
    required String title,
  }) = _MarkdownInfo;
}

class MarkdownViewer extends StatelessWidget {
  const MarkdownViewer({required this.markdownInfo, super.key});

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
        onTapLink: (linkText, linkUrl, linkTitle) async => launchUrl(Uri.parse(linkUrl!)),
      ),
    );
  }
}
