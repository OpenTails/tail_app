import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:tail_app/Frontend/pages/markdown_viewer.dart';
import 'package:tail_app/Frontend/translation_string_definitions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Backend/LoggingWrappers.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../utils.dart';

class More extends ConsumerStatefulWidget {
  const More({super.key});

  @override
  ConsumerState<More> createState() => _MoreState();
}

class _MoreState extends ConsumerState<More> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: Text(joyStickPage()),
          subtitle: Text(joyStickPageDescription()),
          leading: const Icon(Icons.gamepad),
          onTap: () {
            context.push('/joystick');
          },
        ),
        ListTile(
          title: Text(sequencesPage()),
          subtitle: Text(sequencesPageDescription()),
          leading: const Icon(Icons.list),
          onTap: () {
            context.push('/moveLists');
          },
        ),
        ListTile(
          title: Text(audioPage()),
          subtitle: Text(audioEditDescription()),
          leading: const Icon(Icons.audio_file),
          onTap: () {
            context.push('/customAudio');
          },
        ),
        ListTile(
          title: Text(settingsPage()),
          subtitle: Text(settingsDescription()),
          leading: const Icon(Icons.settings),
          onTap: () {
            context.push('/settings');
          },
        ),
        ListTile(
          leading: const Icon(Icons.feedback),
          title: Text(feedbackPage()),
          onTap: () {
            BetterFeedback.of(context).showAndUploadToSentry();
          },
        ),
        ListTile(
          title: Text(
            moreManualTitle(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        PdfWidget(name: moreManualMiTailTitle(), url: "https://thetailcompany.com/mitail.pdf"),
        PdfWidget(name: moreManualEargearTitle(), url: "https://thetailcompany.com/eargear.pdf"),
        PdfWidget(name: moreManualFlutterWingsTitle(), url: "https://thetailcompany.com/flutterwings.pdf"),
        ListTile(
          title: Text(moreManualResponsibleWaggingTitle()),
          subtitle: Text(moreManualSubTitle()),
          onTap: () async {
            context.push('/more/viewMarkdown/', extra: MarkdownInfo(content: await rootBundle.loadString(Assets.responsibleWagging), title: moreManualResponsibleWaggingTitle()));
          },
        ),
        ListTile(
          title: Text(
            moreUsefulLinksTitle(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        ListTile(
          title: const Text("Store"),
          leading: const Icon(Icons.store),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://thetailcompany.com?utm_source=Tail_App'));
          },
        ),
        ListTile(
          title: const Text("Wiki"),
          leading: const Icon(Icons.menu_book),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://docs.thetailcompany.com/?utm_source=Tail_App'));
          },
        ),
        ListTile(
          title: const Text("Telegram"),
          leading: const Icon(Icons.telegram),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://t.me/joinchat/VCdXxqKgRv2yrDNC'));
          },
        ),
        ListTile(
          title: const Text("Support Email"),
          leading: const Icon(Icons.email),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('mailto:info@thetailcompany.com'));
          },
        ),
        ListTile(
          title: Text(moreSourceCode()),
          leading: const Icon(Icons.code),
          trailing: const Icon(Icons.open_in_browser),
          onTap: () async {
            await launchUrl(Uri.parse('https://github.com/Codel1417/tail_app'));
          },
          onLongPress: () {
            if (HiveProxy.getOrDefault(settings, showDebugging, defaultValue: showDebuggingDefault)) {
              return;
            }
            context.push('/settings/developer/pin');
          },
        ),
        ListTile(
          title: Text(morePrivacyPolicyLinkTitle()),
          leading: const Icon(Icons.privacy_tip),
          onTap: () async {
            context.push('/more/viewMarkdown/', extra: MarkdownInfo(content: await rootBundle.loadString(Assets.privacy), title: morePrivacyPolicyLinkTitle()));
          },
        ),
        ListTile(
          title: Text(aboutPage()),
          leading: const Icon(Icons.info),
          onTap: () {
            PackageInfo.fromPlatform().then(
              (value) => showLicensePage(
                context: context,
                useRootNavigator: true,
                applicationVersion: "${value.version} (${value.buildNumber})",
                applicationLegalese: "Developed by Code-Floof for the community. Open Source GPL 3.0 Licensed",
                applicationIcon: Image.asset(
                  Assets.tCLogoTransparentNoText.path,
                  width: 150,
                  height: 150,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class PdfWidget extends StatefulWidget {
  final String name;
  final String url;

  const PdfWidget({super.key, required this.name, required this.url});

  @override
  State<PdfWidget> createState() => _PdfWidgetState();
}

class _PdfWidgetState extends State<PdfWidget> {
  CancelToken cancelToken = CancelToken();
  String filePath = '';
  double progress = 0;

  @override
  void dispose() {
    super.dispose();
    cancelToken.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        widget.name,
      ),
      subtitle: AnimatedCrossFade(
        firstChild: Text(moreManualSubTitle()),
        secondChild: LinearProgressIndicator(
          value: progress,
        ),
        crossFadeState: progress < 1 ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        duration: animationTransitionDuration,
      ),
      onTap: () async {
        filePath = '${(await getTemporaryDirectory()).path}${widget.name}.pdf';
        if (await File(filePath).exists()) {
          if (context.mounted) {
            progress = 0;
            context.push('/more/viewPDF', extra: filePath);
          }
          return;
        }
        final transaction = Sentry.startTransaction('GET PDF', 'http', description: widget.url);
        try {
          setState(() {
            progress = 0.1;
          });
          final rs = await initDio().download(
            widget.url,
            filePath,
            deleteOnError: true,
            cancelToken: cancelToken,
            onReceiveProgress: (current, total) {
              setState(
                () {
                  progress = current / total;
                },
              );
            },
          );
          if (rs.statusCode == 200) {
            if (context.mounted) {
              progress = 0;
              context.push('/more/viewPDF', extra: filePath);
            }
          } else {
            setState(
              () {
                progress = 0;
              },
            );
          }
        } catch (e) {
          transaction.throwable = e;
          transaction.status = const SpanStatus.internalError();
          setState(
            () {
              progress = 0;
            },
          );
        }
        transaction.finish();
      },
    );
  }
}
