import 'package:json_annotation/json_annotation.dart';

part 'firmware_update.g.dart';

@JsonSerializable()
class FWInfo {
  String version;
  String md5sum;
  String url;
  String changelog;
  String glash;

  FWInfo(this.version, this.md5sum, this.url, this.changelog, this.glash);

  factory FWInfo.fromJson(Map<String, dynamic> json) => _$FWInfoFromJson(json);

  Map<String, dynamic> toJson() => _$FWInfoToJson(this);

  @override
  String toString() {
    return 'FWInfo{version: $version}';
  }
}
