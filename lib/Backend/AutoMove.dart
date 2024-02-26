import 'package:tail_app/Backend/Bluetooth/btMessage.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

void ChangeAutoMove(BaseStatefulDevice device) {
  String cmd = '';
  if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
    if (device.baseStoredDevice.autoMove) {
      cmd = "CASUAL T${device.baseStoredDevice.autoMoveMinPause.toInt()}T${device.baseStoredDevice.autoMoveMaxPause.toInt()}";
    } else {
      cmd = "ENDCASUAL";
    }
  } else {
    if (device.baseStoredDevice.autoMove) {
      cmd = "AUTOMODE ";
      for (AutoActionCategory category in device.baseStoredDevice.selectedAutoCategories) {
        cmd = "${cmd}G${category.index}";
      }
      cmd = "$cmd T${device.baseStoredDevice.autoMoveMinPause.toInt()}T${device.baseStoredDevice.autoMoveMaxPause.toInt()}T${(device.baseStoredDevice.autoMoveTotal.toInt() * 60) ~/ 15}";
    } else {
      cmd = "STOPAUTO";
    }
  }
  device.commandQueue.addCommand(BluetoothMessage(cmd, device, Priority.normal));
}
