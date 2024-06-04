import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:platform/platform.dart';
import 'package:tail_app/Frontend/utils.dart';
import 'package:test/test.dart';

// Annotation which generates the cat.mocks.dart library and the MockCat class.
@GenerateNiceMocks([MockSpec<LocalPlatform>()])
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
}
