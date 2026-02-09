import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:logging/logging.dart';
import 'package:tail_app/Frontend/Widgets/known_gear.dart';
import 'package:tail_app/Frontend/Widgets/scan_for_new_device.dart';
import 'package:tail_app/Frontend/Widgets/uwu_text.dart';

import '../../Backend/Bluetooth/bluetooth_manager_plus.dart';
import '../../Backend/logging_wrappers.dart';
import '../../Backend/analytics.dart';
import '../../constants.dart';
import '../../gen/assets.gen.dart';
import '../Widgets/language_picker.dart';
import '../Widgets/lottie_lazy_load.dart';
import '../go_router_config.dart';
import '../translation_string_definitions.dart';
import '../utils.dart';
import 'markdown_viewer.dart';

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
  bool firstTimeOnboarding = true;
  @override
  void initState() {
    super.initState();
    // Users could be thrown into onboarding if the privacy policy changed
    firstTimeOnboarding = HiveProxy.getOrDefault(settings, hasCompletedOnboarding, defaultValue: hasCompletedOnboardingDefault) == hasCompletedOnboardingDefault;
    //skip if going through onboarding a second time
    bluetoothAccepted = !firstTimeOnboarding;
  }

  void _onIntroEnd(BuildContext context) {
    // Navigator.of(context).pushReplacement()
    launchAppAnalytics();
    analyticsEvent(name: "Complete Onboarding", props: {"onboardingVersion": hasCompletedOnboardingVersionToAgree.toString()});
    _introLogger.info("Complete Onboarding");
    HiveProxy.put(settings, hasCompletedOnboarding, hasCompletedOnboardingVersionToAgree);
    const ActionPageRoute().pushReplacement(context);
  }

  Widget _buildImage(String assetName, [double width = 350]) {
    return Image.asset(assetName, width: width);
  }

  @override
  Widget build(BuildContext context) {
    setupSystemColor(context);
    ref.watch(initLocaleProvider);
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
      bodyFlex: 5,
      //safeArea: 0,
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
      showBackButton: true,
      showSkipButton: kDebugMode,
      pages: [
        PageViewModel(
          title: convertToUwU(homeWelcomeMessageTitle()),
          body: convertToUwU(homeWelcomeMessage()),
          image: Builder(
            builder: (context) {
              if (Theme.of(context).colorScheme.brightness == Brightness.light) {
                return _buildImage(Assets.splashLightTransparent.path, MediaQuery.of(context).size.width);
              } else {
                return _buildImage(Assets.splashDarkTransparent.path, MediaQuery.of(context).size.width);
              }
            },
          ),
          footer: LanguagePicker(isButton: true),
          decoration: pageDecoration.copyWith(footerFlex: 1),
        ),
        PageViewModel(
          title: convertToUwU(morePrivacyPolicyLinkTitle()),
          body: convertToUwU(onboardingPrivacyPolicyDescription()),
          image: LottieLazyLoad(asset: Assets.tailcostickers.tailCoStickersFile144834359, width: MediaQuery.of(context).size.width),
          footer: OverflowBar(
            alignment: MainAxisAlignment.center,
            overflowAlignment: OverflowBarAlignment.center,
            overflowSpacing: 4,
            spacing: 8,
            children: [
              ElevatedButton(
                onPressed: () async {
                  MarkdownViewerRoute(
                    $extra: MarkdownInfo(content: await rootBundle.loadString(Assets.privacy), title: convertToUwU(morePrivacyPolicyLinkTitle()), analyticsLabel: "Privacy Policy"),
                  ).push(context);
                },
                child: Text(convertToUwU(onboardingPrivacyPolicyViewButtonLabel())),
              ),
              FilledButton(
                onPressed: privacyAccepted
                    ? null
                    : () async {
                        setState(() {
                          _introLogger.info("Accepted Privacy Policy");
                          privacyAccepted = true;

                          if (firstTimeOnboarding) {
                            // Don't change settings of users who have already completed onboarding once.
                            HiveProxy
                              ..put(settings, allowErrorReporting, true)
                              ..put(settings, allowAnalytics, true);

                            introKey.currentState?.next();
                          } else {
                            introKey.currentState?.skipToEnd();
                          }
                        });
                      },
                child: Text(convertToUwU(onboardingPrivacyPolicyAcceptButtonLabel())),
              ),
            ],
          ),
          decoration: pageDecoration.copyWith(footerFlex: 2),
        ),
        PageViewModel(
          title: convertToUwU(onboardingBluetoothTitle()),
          body: convertToUwU(onboardingBluetoothDescription()),
          image: LottieLazyLoad(asset: Assets.tailcostickers.tailCoStickersFile144834357, width: MediaQuery.of(context).size.width),
          footer: OverflowBar(
            alignment: MainAxisAlignment.center,
            children: [
              FilledButton(
                onPressed: bluetoothAccepted
                    ? null
                    : () async {
                        if (await getBluetoothPermission() == BluetoothPermissionStatus.granted) {
                          setState(() {
                            // Start FlutterBluePlus
                            initFlutterBluePlus();
                            bluetoothAccepted = true;
                          });
                          if (firstTimeOnboarding) {
                            introKey.currentState?.next();
                          } else {
                            introKey.currentState?.skipToEnd();
                          }
                        }
                      },
                child: Text(convertToUwU(onboardingBluetoothRequestButtonLabel())),
              ),
            ],
          ),
          decoration: pageDecoration,
        ),
        PageViewModel(
          title: convertToUwU(scanDevicesOnboardingTitle()),
          bodyWidget: ScanGearList(popOnConnect: false),
          useScrollView: true,
          decoration: pageDecoration.copyWith(bodyFlex: 10, footerFlex: 1, contentMargin: EdgeInsets.all(0)),
          footer: KnownGear(hideScanButton: true),
        ),
        PageViewModel(
          title: convertToUwU(onboardingCompletedTitle()),
          body: "",
          image: LottieLazyLoad(asset: Assets.tailcostickers.tailCoStickersFile144834338, width: MediaQuery.of(context).size.width),
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
      overrideNext: (context, onPressed) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FilledButton(
            onPressed: onPressed,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(convertToUwU(onboardingContinueLabel()), style: const TextStyle(fontWeight: FontWeight.w600)),
                const Icon(Icons.arrow_forward, key: Key('nextPage')),
              ],
            ),
          ),
        ],
      ),

      skip: const Icon(Icons.skip_next),
      back: const Icon(Icons.arrow_back),
      done: FilledButton(
        onPressed: () {
          _onIntroEnd(context);
        },
        child: Text(convertToUwU(onboardingDoneButtonLabel()), style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      dotsFlex: 0,
      isProgress: false,
      controlsPadding: const EdgeInsets.symmetric(vertical: 32),
    );
  }
}
