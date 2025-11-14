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

  factory Version.fromJson(Map<String, dynamic> json) => _$VersionFromJson(json);
}
