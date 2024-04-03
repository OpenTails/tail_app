import 'dart:io';

import 'package:dio/dio.dart';
import 'package:feedback_sentry/feedback_sentry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Frontend/intnDefs.dart';
import 'package:tail_app/main.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';

class More extends ConsumerStatefulWidget {
  More({Key? key}) : super(key: key);

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
        pdfWidget(name: moreManualDigitailTitle(), url: "https://thetailcompany.com/digitail.pdf"),
        pdfWidget(name: moreManualEargearTitle(), url: "https://thetailcompany.com/eargear.pdf"),
        pdfWidget(name: moreManualFlutterWingsTitle(), url: "https://thetailcompany.com/flutterwings.pdf"),
        pdfWidget(name: moreManualMiTailTitle(), url: "https://thetailcompany.com/mitail.pdf"),
        pdfWidget(name: moreManualResponsibleWaggingTitle(), url: "https://thetailcompany.com/responsiblewagging.pdf"),
        ListTile(
          title: Text(
            moreUsefulLinksTitle(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),
        ListTile(
          title: const Text("Tail Company Store"),
          leading: const Icon(Icons.store),
          onTap: () async {
            await launchUrl(Uri.parse('https://thetailcompany.com?utm_source=Tail_App'));
          },
        ),
        ListTile(
          title: const Text("Tail Company Wiki"),
          leading: const Icon(Icons.notes),
          onTap: () async {
            await launchUrl(Uri.parse('https://docs.thetailcompany.com/?utm_source=Tail_App'));
          },
        ),
        ListTile(
          title: const Text("GitHub"),
          leading: const Icon(Icons.code),
          onTap: () async {
            await launchUrl(Uri.parse('https://github.com/Codel1417/tail_app'));
          },
          onLongPress: () {
            if (SentryHive.box(settings).get(showDebugging, defaultValue: showDebuggingDefault)) {
              return;
            }
            context.push('/settings/developer/pin');
          },
        ),
        ListTile(
          title: Text(morePrivacyPolicyLinkTitle()),
          leading: const Icon(Icons.privacy_tip),
          onTap: () async {
            await launchUrl(Uri.parse('https://github.com/Codel1417/tail_app/blob/master/PRIVACY.md'));
          },
        ),
        ListTile(
          title: Text(aboutPage()),
          leading: const Icon(Icons.info),
          onTap: () {
            PackageInfo.fromPlatform().then(
              (value) => Navigator.push(
                context,
                DialogRoute(
                    builder: (context) => AboutDialog(
                          applicationName: title(),
                          applicationVersion: "${value.version}+${value.buildNumber}",
                          applicationIcon: const Image(
                            image: AssetImage('assets/copilot_fox_icon.png'),
                            height: 60,
                            width: 60,
                          ),
                          applicationLegalese: "This is a fan made app to control 'The Tail Company' tails and ears",
                        ),
                    context: context),
              ),
            );
          },
        ),
      ],
    );
  }
}

class pdfWidget extends StatefulWidget {
  String name;
  String url;

  pdfWidget({super.key, required this.name, required this.url});

  @override
  State<pdfWidget> createState() => _pdfWidgetState();
}

class _pdfWidgetState extends State<pdfWidget> {
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
          final Response rs = await initDio().download(
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
