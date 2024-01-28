import 'package:tail_app/Backend/Bluetooth/btMessage.dart';
import 'package:tail_app/Backend/Definitions/Device/BaseDeviceDefinition.dart';

//TODO: call on device connect
void ChangeAutoMove(BaseStatefulDevice device) {
  String cmd = '';
  if (device.baseDeviceDefinition.deviceType == DeviceType.ears) {
    if (device.baseStoredDevice.autoMove) {
      cmd = "CASUAL T${device.baseStoredDevice.autoMoveMinPause}T${device.baseStoredDevice.autoMoveMaxPause}";
    } else {
      cmd = "ENDCASUAL";
    }
  } else {
    cmd = "AUTOMODE ";
    for (AutoActionCategory category in device.baseStoredDevice.selectedAutoCategories) {
      cmd = "${cmd}G${category.index}";
    }
    cmd = "$cmd T${device.baseStoredDevice.autoMoveMinPause}T${device.baseStoredDevice.autoMoveMaxPause}T${(device.baseStoredDevice.autoMoveTotal * 60) / 15}";
  }
  device.commandQueue.addCommand(BluetoothMessage(cmd, device, Priority.normal));
}
