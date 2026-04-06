import 'package:hive_ce/hive.dart';
import 'package:logarte/logarte.dart';

// ignore: library_private_types_in_public_api
_HiveProxyImpl HiveProxy = _HiveProxyImpl();

class _HiveProxyImpl {
  Future<void> put<E>(String box, dynamic key, E value) {
    logarte.database(target: '$key', value: '$value', source: box);
    return Hive.box(box).put(key, value);
  }

  Future<void> deleteKey(String box, dynamic key) {
    return Hive.box(box).delete(key);
  }

  E getOrDefault<E>(String box, dynamic key, {required E? defaultValue}) {
    return Hive.box(box).get(key, defaultValue: defaultValue)!;
  }
}

final Logarte logarte = Logarte(
  // Whether to ignore the password
  ignorePassword: true,
  disableDebugConsoleLogs: true,
);
