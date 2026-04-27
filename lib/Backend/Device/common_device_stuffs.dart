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

String getNameFromBTName(String bluetoothDeviceName) {
  switch (bluetoothDeviceName) {
    case 'EarGear':
      return 'EarGear';
    case 'EG2':
      return 'EarGear 2';
    case 'mitail':
      return 'MiTail';
    case 'minitail':
      return 'Mini';
    case 'flutter':
      return 'FlutterWings';
    case '(!)Tail1':
      return 'DigiTail';
    case 'clawgear':
      return 'Claws';
  }
  return bluetoothDeviceName;
}
