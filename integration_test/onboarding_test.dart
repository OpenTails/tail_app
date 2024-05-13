import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tail_app/Frontend/intn_defs.dart';
import 'package:tail_app/Frontend/pages/intro.dart';
import 'package:tail_app/constants.dart';
import 'package:tail_app/main.dart';

//final IntegrationTestWidgetsFlutterBinding binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

void main() {
  initHive();
  testWidgets('Launch Onboarding screen, Tap Next', (tester) async {
    // Load app widget.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [],
        child: MaterialApp(
          // required to get the dimensions for the scaffold
          builder: (context, child) => const OnBoardingPage(),
        ),
      ),
    );

    // Verify the onboarding page is visible
    expect(find.text(title()), findsOneWidget);

    // find the next page button
    final nextPage = find.byKey(const Key('nextPage'));
    // Emulate a tap on the floating action button.
    await tester.tap(nextPage);

    // Trigger a frame.
    await tester.pump(animationTransitionDuration);

    // Verify the counter increments by 1.
    expect(find.text(morePrivacyPolicyLinkTitle()), findsOneWidget);
    expect(find.text(title()), findsNothing);

    final acceptPrivacy = find.widgetWithText(Align, 'Accept Privacy Policy');
    await tester.tap(acceptPrivacy);
    await tester.pump(animationTransitionDuration);
    expect(find.text(morePrivacyPolicyLinkTitle()), findsNothing);
    //await binding.convertFlutterSurfaceToImage();
    //await binding.takeScreenshot('screenshot-2');
  });
}
