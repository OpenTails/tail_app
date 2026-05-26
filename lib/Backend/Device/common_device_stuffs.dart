import 'package:hive_ce/hive.dart';

part 'common_device_stuffs.g.dart';

@HiveType(typeId: 15)
enum GlowtipStatus {
  @HiveField(1)
  glowtip,
  @HiveField(2)
  noGlowtip,
  @HiveField(3)
  unknown,
}

@HiveType(typeId: 16)
enum RGBStatus {
  @HiveField(1)
  rgb,
  @HiveField(2)
  noRGB,
  @HiveField(3)
  unknown,
}
