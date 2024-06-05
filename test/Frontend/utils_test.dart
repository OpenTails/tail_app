import 'package:flutter/material.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:tail_app/constants.dart';
import 'package:test/test.dart';

// Annotation which generates the cat.mocks.dart library and the MockCat class.
@GenerateNiceMocks([MockSpec<LocalPlatform>(), MockSpec<BuildContext>()])
import 'utils_test.mocks.dart';

void main() {
  platform = MockLocalPlatform();
  test('Get UTM String for outbound URLs', () {
    when(platform.isAndroid).thenReturn(true);
    when(platform.isIOS).thenReturn(false);
    String response = getOutboundUtm();
    expect(response, "?utm_medium=Tail_App?utm_source=tailappandr");

    when(platform.isAndroid).thenReturn(false);
    when(platform.isIOS).thenReturn(true);
    response = getOutboundUtm();
    expect(response, "?utm_medium=Tail_App?utm_source=tailappios");
  });

  test('Get text color', () {
    Color color = getTextColor(Colors.white);
    expect(color, Typography.material2021().black.labelLarge!.color!);
    color = getTextColor(Colors.black);
    expect(color, Typography.material2021().white.labelLarge!.color!);
    color = getTextColor(Colors.yellowAccent);
    expect(color, Typography.material2021().black.labelLarge!.color!);
    color = getTextColor(Color(appColorDefault));
    expect(color, Typography.material2021().white.labelLarge!.color!);
  });

  test('Get version from string', () {
    Version version = getVersionSemVer("");
    expect(version, Version(0, 0, 0));
    version = getVersionSemVer("5.1.3b");
    expect(version, Version(5, 1, 3));
    version = getVersionSemVer("VER 5.2.5");
    expect(version, Version(5, 2, 5));
  });
}
