import 'package:freezed_annotation/freezed_annotation.dart';

part 'firmware_update.freezed.dart';
part 'firmware_update.g.dart';

@freezed
class FWInfo with _$FWInfo {
  FWInfo._();

  factory FWInfo({
    required String version,
    required String md5sum,
    required String url,
    @Default("") String changelog,
    @Default("") String glash,
  }) = _FWInfo;

  factory FWInfo.fromJson(Map<String, dynamic> json) => _$FWInfoFromJson(json);

  @override
  String toString() {
    return 'FWInfo{version: $version}';
  }
}
