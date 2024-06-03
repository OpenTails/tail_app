import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Backend/Bluetooth/bluetooth_manager_plus.dart';
import 'package:tail_app/Frontend/Widgets/lottie_lazy_load.dart';
import 'package:tail_app/Frontend/translation_string_definitions.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Backend/LoggingWrappers.dart';
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
  final Logger _introLogger = Logger("Onboarding");
  final introKey = GlobalKey<IntroductionScreenState>();
  bool bluetoothAccepted = false;
  bool privacyAccepted = false;

  void _onIntroEnd(BuildContext context) {
    // Navigator.of(context).pushReplacement()
    plausible.event(name: "Complete Onboarding");
    _introLogger.info("Complete Onboarding");
    HiveProxy.put(settings, hasCompletedOnboarding, hasCompletedOnboardingVersionToAgree);
    context.pushReplacement('/');
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset(
      assetName,
      width: width,
    );
  }

  @override
  Widget build(BuildContext context) {
    setupSystemColor(context);
    var pageDecoration = PageDecoration(
      titleTextStyle: const TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: const TextStyle(fontSize: 19.0),
      bodyPadding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 16.0),
      pageColor: Theme.of(context).canvasColor,
      imagePadding: EdgeInsets.zero,
      footerFlex: 3,
      bodyAlignment: Alignment.center,
      footerPadding: const EdgeInsets.symmetric(vertical: 16),
      imageFlex: 5,
      bodyFlex: 6,
      safeArea: 0,
    );
    return ValueListenableBuilder(
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
                    context.push("/settings/developer/logs");
                  },
                ),
              ),
            ),
          ),
          pages: [
            PageViewModel(
              title: homeWelcomeMessageTitle(),
              body: homeWelcomeMessage(),
              image: Builder(
                builder: (context) {
                  if (Theme.of(context).colorScheme.brightness == Brightness.light) {
                    return _buildImage(Assets.splashLightTransparent.path, MediaQuery.of(context).size.width);
                  } else {
                    return _buildImage(Assets.splashDarkTransparent.path, MediaQuery.of(context).size.width);
                  }
                },
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
              footer: ButtonBar(
                alignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
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
                              _introLogger.info("Accepted Privacy Policy");
                              privacyAccepted = true;
                              HiveProxy.put(settings, allowErrorReporting, true);
                              HiveProxy.put(settings, allowAnalytics, true);
                              introKey.currentState?.next();
                            });
                          },
                    child: Text(
                      onboardingPrivacyPolicyAcceptButtonLabel(),
                    ),
                  )
                ],
              ),
              decoration: pageDecoration,
            ),
            PageViewModel(
              title: onboardingBluetoothTitle(),
              body: onboardingBluetoothDescription(),
              image: LottieLazyLoad(
                asset: Assets.tailcostickers.tailCoStickersFile144834357,
                width: MediaQuery.of(context).size.width,
              ),
              footer: ButtonBar(
                alignment: MainAxisAlignment.center,
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
              decoration: pageDecoration,
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
                imagePadding: const EdgeInsets.symmetric(vertical: 32),
                contentMargin: const EdgeInsets.only(top: 32),
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
          dotsFlex: 1,
          controlsPadding: const EdgeInsets.symmetric(vertical: 32),
          dotsDecorator: DotsDecorator(
            size: const Size.square(10.0),
            activeSize: const Size(40.0, 10.0),
            activeColor: Theme.of(context).colorScheme.primary,
            color: Theme.of(context).colorScheme.tertiary,
            spacing: const EdgeInsets.symmetric(horizontal: 3.0),
            activeShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50.0)),
          ),
        );
      },
    );
  }
}
