import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive_ce/hive.dart';

part 'version.freezed.dart';

part 'version.g.dart';

@freezed
@HiveType(typeId: 17)
abstract class Version with _$Version implements Comparable<Version> {
  const Version._();

  @Implements<Comparable<Version>>()
  const factory Version({
    @Default(0) @HiveField(0) final int major,
    @Default(0) @HiveField(1) final int minor,
    @Default(0) @HiveField(2) final int patch,
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

  factory Version.fromJson(Map<String, dynamic> json) =>
      _$VersionFromJson(json);

  // for the version from PackageInfo
  factory Version.fromString(String string) {
    List<String> split = string.split(".");
    if (split.length != 3) {
      throw FormatException("Version string is not semver 1.0.0");
    }
    return Version(
      major: int.parse(split[0]),
      minor: int.parse(split[1]),
      patch: int.parse(split[2]),
    );
  }

  static Version getFromSemVer(String input) {
    String major = "0";
    String minor = "0";
    String patch = "0";
    List<String> split = input.split(" ").last.split(".");
    if (split.isNotEmpty && int.tryParse(split[0]) != null) {
      major = split[0];
    }
    if (split.length > 1 && int.tryParse(split[1]) != null) {
      minor = split[1];
    }
    if (split.length > 2 &&
        int.tryParse(split[2].replaceAll(RegExp('[^0-9]'), '')) != null) {
      patch = split[2].replaceAll(RegExp('[^0-9]'), '');
    }
    return Version(
      major: int.parse(major),
      minor: int.parse(minor),
      patch: int.parse(patch),
    );
  }
}
