import 'package:hive_ce/hive.dart';
import 'package:logarte/logarte.dart';

import '../constants.dart';

// ignore: library_private_types_in_public_api
_HiveProxyImpl HiveProxy = _HiveProxyImpl();
List<String> genericBoxes = [settings];

class _HiveProxyImpl {
  Future<void> put<E>(String box, dynamic key, E value) {
    logarte.database(
      target: '$key',
      value: '$value',
      source: box,
    );
    if (genericBoxes.contains(box)) {
      return Hive.box(box).put(key, value);
    } else {
      return Hive.box<E>(box).put(key, value);
    }
  }

  Future<void> deleteKey<E>(String box, dynamic key) {
    if (genericBoxes.contains(box)) {
      return Hive.box(box).delete(key);
    } else {
      return Hive.box<E>(box).delete(key);
    }
  }

  E getOrDefault<E>(String box, dynamic key, {required E? defaultValue}) {
    if (genericBoxes.contains(box)) {
      return Hive.box(box).get(key, defaultValue: defaultValue)!;
    } else {
      return Hive.box<E>(box).get(key, defaultValue: defaultValue)!;
    }
  }

  Future<int> clear<E>(String box) {
    if (genericBoxes.contains(box)) {
      return Hive.box(box).clear();
    } else {
      return Hive.box<E>(box).clear();
    }
  }

  Future<Iterable<int>> addAll<E>(String name, Iterable<E> values) {
    return Hive.box<E>(name).addAll(values);
  }

  Iterable<E> getAll<E>(String name) {
    return Hive.box<E>(name).values;
  }
}

final Logarte logarte = Logarte(
  // Whether to ignore the password
  ignorePassword: true,
  disableDebugConsoleLogs: true,
);
