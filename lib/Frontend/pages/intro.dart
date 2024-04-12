import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:lottie/lottie.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager.dart';
import 'package:tail_app/Frontend/intn_defs.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../main.dart';
import '../utils.dart';

class OnBoardingPage extends ConsumerStatefulWidget {
  const OnBoardingPage({super.key});

  @override
  OnBoardingPageState createState() => OnBoardingPageState();
}

class OnBoardingPageState extends ConsumerState<OnBoardingPage> {
  final introKey = GlobalKey<IntroductionScreenState>();
  bool bluetoothAccepted = false;
  bool privacyAccepted = false;

  void _onIntroEnd(BuildContext context) {
    // Navigator.of(context).pushReplacement()
    plausible.event(name: "Complete Onboarding");
    SentryHive.box(settings).put(hasCompletedOnboarding, true);
    context.pushReplacement('/');
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset('assets/$assetName', width: width);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Theme.of(context).canvasColor,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Theme.of(context).canvasColor,
            ),
    );
    const bodyStyle = TextStyle(fontSize: 19.0);
    bool bluetoothPoweredOff = ref.watch(btStatusProvider).valueOrNull == BleStatus.poweredOff;
    var pageDecoration = PageDecoration(
      titleTextStyle: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Theme.of(context).canvasColor,
      imagePadding: EdgeInsets.zero,
    );

    return SafeArea(
        child: IntroductionScreen(
      key: introKey,
      canProgress: (page) {
        if (page == 2 && !bluetoothAccepted && !bluetoothPoweredOff) {
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
            child: _buildImage('copilot_fox_icon.png', 60),
          ),
        ),
      ),
      pages: [
        PageViewModel(
          title: title(),
          body: subTitle(),
          image: Lottie.asset(
            width: MediaQuery.of(context).size.width,
            renderCache: RenderCache.raster,
            backgroundLoading: true,
            'assets/tailcostickers/tgs/TailCoStickers_file_144834354.tgs',
            decoder: LottieComposition.decodeGZip,
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: morePrivacyPolicyLinkTitle(),
          body: onboardingPrivacyPolicyDescription(),
          image: Lottie.asset(
            renderCache: RenderCache.raster,
            width: MediaQuery.of(context).size.width,
            backgroundLoading: true,
            'assets/tailcostickers/tgs/TailCoStickers_file_144834359.tgs',
            decoder: LottieComposition.decodeGZip,
          ),
          footer: Center(
            child: Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: () async {
                    await launchUrl(Uri.parse('https://github.com/Codel1417/tail_app/blob/master/PRIVACY.md'));
                  },
                  child: Text(
                    onboardingPrivacyPolicyViewButtonLabel(),
                  ),
                ),
                FilledButton(
                  onPressed: privacyAccepted
                      ? null
                      : () {
                          setState(() {
                            privacyAccepted = true;
                            SentryHive.box(settings).put(allowErrorReporting, true);
                            SentryHive.box(settings).put(allowAnalytics, true);
                            introKey.currentState?.next();
                          });
                        },
                  child: Text(
                    onboardingPrivacyPolicyAcceptButtonLabel(),
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
          title: onboardingBluetoothTitle(),
          body: onboardingBluetoothDescription(),
          image: Lottie.asset(
            renderCache: RenderCache.raster,
            width: MediaQuery.of(context).size.width,
            backgroundLoading: true,
            'assets/tailcostickers/tgs/TailCoStickers_file_144834357.tgs',
            decoder: LottieComposition.decodeGZip,
          ),
          footer: Center(
            child: Wrap(
              spacing: 10,
              children: [
                FilledButton(
                  onPressed: !bluetoothPoweredOff
                      ? null
                      : () {
                          AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
                        },
                  child: Text(
                    onboardingBluetoothEnableButtonLabel(),
                  ),
                ),
                FilledButton(
                  onPressed: bluetoothAccepted
                      ? null
                      : () async {
                          if (await getBluetoothPermission()) {
                            setState(
                              () {
                                bluetoothAccepted = true;
                              },
                            );
                            introKey.currentState?.next();
                          }
                        },
                  child: Text(
                    onboardingBluetoothRequestButtonLabel(),
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
          title: onboardingCompletedTitle(),
          body: "",
          image: Lottie.asset(
            renderCache: RenderCache.raster,
            width: MediaQuery.of(context).size.width,
            backgroundLoading: true,
            'assets/tailcostickers/tgs/TailCoStickers_file_144834338.tgs',
            decoder: LottieComposition.decodeGZip,
          ),
          decoration: pageDecoration.copyWith(
            bodyFlex: 2,
            imageFlex: 4,
            bodyAlignment: Alignment.bottomCenter,
            imageAlignment: Alignment.topCenter,
          ),
          reverse: true,
        ),
      ],
      onDone: () => _onIntroEnd(context),
      onSkip: () => _onIntroEnd(context),
      // You can override onSkip callback
      //rtl: true, // Display as right-to-left
      back: const Icon(Icons.arrow_back),
      next: const Icon(Icons.arrow_forward),
      done: FilledButton(
        onPressed: () {
          _onIntroEnd(context);
        },
        child: Text(onboardingDoneButtonLabel(), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    ));
  }
}
