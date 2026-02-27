import 'package:flutter_test/flutter_test.dart';
import 'package:tail_app/Backend/version.dart';

void main() {
  group('Version', () {
    test('default constructor creates 0.0.0', () {
      final v = Version();
      expect(v.major, 0);
      expect(v.minor, 0);
      expect(v.patch, 0);
    });

    test('compareTo orders correctly', () {
      final v1 = Version(major: 1, minor: 2, patch: 3);
      final v2 = Version(major: 1, minor: 2, patch: 4);
      final v3 = Version(major: 1, minor: 3, patch: 0);
      final v4 = Version(major: 2, minor: 0, patch: 0);

      expect(v1.compareTo(v2), lessThan(0));
      expect(v2.compareTo(v1), greaterThan(0));
      expect(v1.compareTo(v3), lessThan(0));
      expect(v4.compareTo(v3), greaterThan(0));
    });

    test('operator < > <= >= work', () {
      final vA = Version(major: 0, minor: 5, patch: 10);
      final vB = Version(major: 1, minor: 0, patch: 0);
      expect(vA < vB, isTrue); // major lower
      expect(vB > vA, isTrue);
      
      final vC = Version(major: 1, minor: 2, patch: 3);
      final vD = Version(major: 1, minor: 2, patch: 4);
      expect(vC < vD, isTrue); // patch lower
      expect(vD > vC, isTrue);
      
      final vE = Version(major: 1, minor: 2, patch: 3);
      final vF = Version(major: 1, minor: 2, patch: 3);
      expect(vE <= vF, isTrue); // equal
      expect(vF >= vE, isTrue);
    });

    test('fromJson creates correct instance', () {
      final json = {'major': 3, 'minor': 4, 'patch': 5};
      final v = Version.fromJson(json);
      expect(v.major, 3);
      expect(v.minor, 4);
      expect(v.patch, 5);
    });
  });
}
