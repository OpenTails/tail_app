import 'package:permission_handler/permission_handler.dart';

import '../../Frontend/utils.dart';

//TODO: Unify permission classes
class TriggerPermissionHandle {
  final Set<Permission> android;
  final Set<Permission> ios;

  const TriggerPermissionHandle({this.android = const {}, this.ios = const {}});

  Future<bool> hasAllPermissions() async {
    if (platform.isAndroid) {
      for (Permission permission in android) {
        PermissionStatus permissionStatus = await permission.request();
        if (PermissionStatus.granted != permissionStatus) {
          return false;
        }
      }
    }
    if (platform.isIOS) {
      for (Permission permission in ios) {
        PermissionStatus permissionStatus = await permission.request();
        if (PermissionStatus.granted != permissionStatus) {
          return false;
        }
      }
    }
    return true;
  }
}
