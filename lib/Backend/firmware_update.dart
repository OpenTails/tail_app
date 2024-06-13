import 'package:freezed_annotation/freezed_annotation.dart';

part 'firmware_update.freezed.dart';
part 'firmware_update.g.dart';

@freezed
class FWInfo with _$FWInfo {
  const factory FWInfo({
    required String version,
    required String md5sum,
    required String url,
    @Default("") final String changelog,
    @Default("") final String glash,
  }) = _FWInfo;

  factory FWInfo.fromJson(Map<String, dynamic> json) => _$FWInfoFromJson(json);
}
