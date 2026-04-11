import "package:hive_ce/hive.dart";
import "package:tail_app/vendor/aptabase/storage_manager.dart";

class StorageManagerHive extends StorageManager {
  final _eventBoxName = "aptabaseEvents";
  late LazyBox<String> _eventBox;

  @override
  Future<void> init() async {
    _eventBox = await Hive.openLazyBox(_eventBoxName);

    return super.init();
  }

  @override
  Future<void> addEvent(String key, String event) async {
    await _eventBox.put(key, event);
  }

  @override
  Future<void> deleteEvents(Set<String> keys) async {
    Iterable<dynamic> keys = _eventBox.keys;
    for (var key in keys) {
      if (keys.contains(key)) {
        _eventBox.delete(key);
      }
    }
  }

  @override
  Future<Iterable<MapEntry<String, String>>> getItems(int length) async {
    List<MapEntry<String, String>> events = [];
    for (var key in _eventBox.keys.take(length)) {
      String? value = await _eventBox.get(key);

      if (value == null) {
        continue;
      }
      events.add(MapEntry(key, value));
    }
    return events;
  }
}
