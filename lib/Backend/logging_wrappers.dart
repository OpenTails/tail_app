import 'package:logarte/logarte.dart';
import 'package:sentry_hive/sentry_hive.dart';

import '../constants.dart';

// ignore: library_private_types_in_public_api
_HiveProxyImpl HiveProxy = _HiveProxyImpl();
List<String> genericBoxes = [settings, notificationBox];

class _HiveProxyImpl {
  Future<void> put<E>(String box, dynamic key, E value) {
    logarte.database(
      target: '$key',
      value: '$value',
      source: box,
    );
    if (genericBoxes.contains(box)) {
      return SentryHive.box(box).put(key, value);
    } else {
      return SentryHive.box<E>(box).put(key, value);
    }
  }

  Future<void> deleteKey<E>(String box, dynamic key) {
    if (genericBoxes.contains(box)) {
      return SentryHive.box(box).delete(key);
    } else {
      return SentryHive.box<E>(box).delete(key);
    }
  }

  E getOrDefault<E>(String box, dynamic key, {E? defaultValue}) {
    if (genericBoxes.contains(box)) {
      return SentryHive.box(box).get(key, defaultValue: defaultValue)!;
    } else {
      return SentryHive.box<E>(box).get(key, defaultValue: defaultValue)!;
    }
  }

  Future<int> clear<E>(String box) {
    if (genericBoxes.contains(box)) {
      return SentryHive.box(box).clear();
    } else {
      return SentryHive.box<E>(box).clear();
    }
  }

  Future<Iterable<int>> addAll<E>(String name, Iterable<E> values) {
    return SentryHive.box<E>(name).addAll(values);
  }

  Iterable<E> getAll<E>(String name) {
    return SentryHive.box<E>(name).values;
  }
}

final Logarte logarte = Logarte(
  // Whether to ignore the password
  ignorePassword: true,
  disableDebugConsoleLogs: true,
);
