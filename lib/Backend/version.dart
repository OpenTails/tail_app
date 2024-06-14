import 'package:freezed_annotation/freezed_annotation.dart';

part 'version.freezed.dart';

@freezed
class Version with _$Version implements Comparable<Version> {
  const Version._();

  @Implements<Comparable<Version>>()
  const factory Version({
    @Default(0) final int major,
    @Default(0) final int minor,
    @Default(0) final int patch,
  }) = _Version;

  @override
  int compareTo(Version other) {
    if (major != other.major) {
      return major.compareTo(other.major);
    }
    if (minor != other.minor) {
      return minor.compareTo(other.minor);
    }
    if (patch != other.patch) {
      return patch.compareTo(other.patch);
    }
    return 0;
  }

  bool operator <(Version other) => compareTo(other) < 0;

  bool operator >(Version other) => compareTo(other) > 0;

  bool operator <=(Version other) => compareTo(other) <= 0;

  bool operator >=(Version other) => compareTo(other) >= 0;
}
