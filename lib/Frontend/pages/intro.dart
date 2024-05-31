import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:logging/logging.dart';
import 'package:logging_flutter/logging_flutter.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Frontend/Widgets/lottie_lazy_load.dart';
import 'package:tail_app/Frontend/translation_string_definitions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../../main.dart';
import '../utils.dart';

class OnBoardingPage extends ConsumerStatefulWidget {
  const OnBoardingPage({super.key});

  @override
  OnBoardingPageState createState() => OnBoardingPageState();
}

class OnBoardingPageState extends ConsumerState<OnBoardingPage> {
  Logger _introLogger = Logger("Onboarding");
  final introKey = GlobalKey<IntroductionScreenState>();
  bool bluetoothAccepted = false;
  bool privacyAccepted = false;

  void _onIntroEnd(BuildContext context) {
    // Navigator.of(context).pushReplacement()
    plausible.event(name: "Complete Onboarding");
    _introLogger.info("Complete Onboarding");
    SentryHive.box(settings).put(hasCompletedOnboarding, hasCompletedOnboardingVersionToAgree);
    context.pushReplacement('/');
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset(
      assetName,
      width: width,
      cacheWidth: width.toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Theme.of(context).canvasColor, systemNavigationBarColor: Theme.of(context).canvasColor)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Theme.of(context).canvasColor, systemNavigationBarColor: Theme.of(context).canvasColor),
    );
    const bodyStyle = TextStyle(fontSize: 19.0);
    var pageDecoration = PageDecoration(
      titleTextStyle: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Theme.of(context).canvasColor,
      imagePadding: EdgeInsets.zero,
      footerFlex: 0,
      footerPadding: EdgeInsets.zero,
    );

    return SafeArea(
      child: ValueListenableBuilder(
        valueListenable: isBluetoothEnabled,
        builder: (BuildContext context, bool bluetoothEnabled, Widget? child) {
          return IntroductionScreen(
            key: introKey,
            canProgress: (page) {
              if (page == 2 && !bluetoothAccepted && bluetoothEnabled) {
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
                  child: InkWell(
                    child: _buildImage(Assets.tCLogoTransparentNoText.path, 60),
                    onLongPress: () {
                      _introLogger.info("Open Logs");
                      LogConsole.open(context);
                    },
                  ),
                ),
              ),
            ),
            pages: [
              PageViewModel(
                title: homeWelcomeMessageTitle(),
                body: homeWelcomeMessage(),
                image: LottieLazyLoad(
                  asset: Assets.tailcostickers.tailCoStickersFile144834354,
                  width: MediaQuery.of(context).size.width,
                ),
                decoration: pageDecoration,
              ),
              PageViewModel(
                title: morePrivacyPolicyLinkTitle(),
                body: onboardingPrivacyPolicyDescription(),
                image: LottieLazyLoad(
                  asset: Assets.tailcostickers.tailCoStickersFile144834359,
                  width: MediaQuery.of(context).size.width,
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
                                  _introLogger.info("Accepted Privact Policy");
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
                image: LottieLazyLoad(
                  asset: Assets.tailcostickers.tailCoStickersFile144834357,
                  width: MediaQuery.of(context).size.width,
                ),
                footer: Center(
                  child: Wrap(
                    spacing: 10,
                    children: [
                      FilledButton(
                        onPressed: bluetoothEnabled
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
                                if (await getBluetoothPermission(_introLogger)) {
                                  setState(
                                    () {
                                      // Start FlutterBluePlus
                                      if (!ref.exists(initFlutterBluePlusProvider)) {
                                        ref.read(initFlutterBluePlusProvider);
                                      }
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
                image: LottieLazyLoad(
                  asset: Assets.tailcostickers.tailCoStickersFile144834338,
                  width: MediaQuery.of(context).size.width,
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
            next: const Icon(
              Icons.arrow_forward,
              key: Key('nextPage'),
            ),
            done: FilledButton(
              onPressed: () {
                _onIntroEnd(context);
              },
              child: Text(onboardingDoneButtonLabel(), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          );
        },
      ),
    );
  }
}
