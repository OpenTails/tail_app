import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sentry_hive/sentry_hive.dart';
import 'package:tail_app/main.dart';

Future<void> deleteHive() async {
  await SentryHive.deleteFromDisk();
}

class FakePathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async {
    return 'test/temp/';
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return 'test/support/';
  }

  @override
  Future<String?> getLibraryPath() async {
    return 'test/library/';
  }

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return 'test/application/';
  }

  @override
  Future<String?> getExternalStoragePath() async {
    return 'test/external/';
  }

  @override
  Future<List<String>?> getExternalCachePaths() async {
    return <String>['test/externalCache/'];
  }

  @override
  Future<List<String>?> getExternalStoragePaths({
    StorageDirectory? type,
  }) async {
    return <String>['test/external/'];
  }

  @override
  Future<String?> getDownloadsPath() async {
    return 'test/downloads/';
  }
}

Future<void> setupHive() async {
  PathProviderPlatform.instance = FakePathProviderPlatform();
  await initHive();
}
