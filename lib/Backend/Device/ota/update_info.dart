import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_info.freezed.dart';

part 'update_info.g.dart';

@freezed
abstract class FWInfo with _$FWInfo {
  const factory FWInfo({
    required String version,
    required String md5sum,
    required String url,
    required List<String> supportedHardwareVersions,
    required String minimumAppVersion,
    @Default("") final String changelog,
    @Default("") final String glash,
  }) = _FWInfo;

  factory FWInfo.fromJson(Map<String, dynamic> json) => _$FWInfoFromJson(json);
}
