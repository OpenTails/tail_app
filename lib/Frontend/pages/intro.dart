import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Frontend/intnDefs.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';

class OnBoardingPage extends StatefulWidget {
  const OnBoardingPage({super.key});

  @override
  OnBoardingPageState createState() => OnBoardingPageState();
}

class OnBoardingPageState extends State<OnBoardingPage> {
  final introKey = GlobalKey<IntroductionScreenState>();
  bool bluetoothAccepted = false;
  bool privacyAccepted = false;

  void _onIntroEnd(BuildContext context) {
    // Navigator.of(context).pushReplacement()
    SentryHive.box(settings).put(hasCompletedOnboarding, true);
    context.pushReplacement('/');
  }

  Widget _buildFullscreenImage() {
    return Image.asset(
      'assets/fullscreen.jpg',
      fit: BoxFit.cover,
      height: double.infinity,
      width: double.infinity,
      alignment: Alignment.center,
    );
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset('assets/$assetName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    const bodyStyle = TextStyle(fontSize: 19.0);

    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      bodyPadding: EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Colors.white,
      imagePadding: EdgeInsets.zero,
    );

    return IntroductionScreen(
      key: introKey,
      canProgress: (page) {
        if (page == 2 && !bluetoothAccepted) {
          return false;
        } else if (page == 1 && !privacyAccepted) {
          return false;
        }
        return true;
      },
      globalBackgroundColor: Theme.of(context).canvasColor,
      allowImplicitScrolling: true,
      globalHeader: Align(
        alignment: Alignment.topRight,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, right: 16),
            child: _buildImage('copilot_fox_icon.png', 100),
          ),
        ),
      ),
      pages: [
        PageViewModel(
          title: title(),
          body: subTitle(),
          image: _buildImage('copilot_fox_icon.png', 300),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: morePrivacyPolicyLinkTitle(),
          body: "While the data collected is anonymous and can't be used to identify a specific user, you still need to accept the privacy policy",
          image: const Icon(
            Icons.privacy_tip,
            size: 200,
          ),
          footer: Center(
            child: Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: () async {
                    await launchUrl(Uri.parse('https://github.com/Codel1417/tail_app/blob/master/PRIVACY.md'));
                  },
                  child: const Text(
                    'View Privacy Policy',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    Permission.bluetoothScan.request().then(
                      (value) {
                        if (value == PermissionStatus.granted) {
                          setState(
                            () {
                              privacyAccepted = true;
                            },
                          );
                        }
                      },
                    );
                  },
                  child: const Text(
                    'Accept Privacy Policy',
                  ),
                )
              ],
            ),
          ),
          decoration: pageDecoration.copyWith(
            bodyFlex: 6,
            imageFlex: 6,
            safeArea: 80,
          ),
        ),
        PageViewModel(
          title: "Bluetooth",
          body: "Bluetooth permission is required to connect to gear",
          image: const Icon(
            Icons.bluetooth,
            size: 200,
          ),
          footer: Center(
            child: Wrap(
              children: [
                FilledButton(
                  onPressed: () async {
                    PermissionStatus value = await Permission.bluetoothScan.request();
                    if (value == PermissionStatus.granted) {
                      setState(
                        () {
                          bluetoothAccepted = true;
                        },
                      );
                    }
                  },
                  child: const Text(
                    'Grant Permission',
                  ),
                )
              ],
            ),
          ),
          decoration: pageDecoration.copyWith(
            bodyFlex: 6,
            imageFlex: 6,
            safeArea: 80,
          ),
        ),
        PageViewModel(
          title: "Title of last page - reversed",
          bodyWidget: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Click on ", style: bodyStyle),
              Icon(Icons.edit),
              Text(" to edit a post", style: bodyStyle),
            ],
          ),
          decoration: pageDecoration.copyWith(
            bodyFlex: 2,
            imageFlex: 4,
            bodyAlignment: Alignment.bottomCenter,
            imageAlignment: Alignment.topCenter,
          ),
          image: _buildImage('img1.jpg'),
          reverse: true,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      // You can override onSkip callback
      //rtl: true, // Display as right-to-left
      back: const Icon(Icons.arrow_back),
      next: const Icon(Icons.arrow_forward),
      done: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
