import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' as flTest;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:quick_actions_platform_interface/quick_actions_platform_interface.dart';
import 'package:tail_app/Backend/Definitions/Action/base_action.dart';
import 'package:tail_app/Backend/action_registry.dart';
import 'package:tail_app/Backend/favorite_actions.dart';
import 'package:tail_app/Backend/logging_wrappers.dart';
import 'package:tail_app/constants.dart';

import '../testing_utils/hive_utils.dart';

void main() {
  setUp(() async {
    flTest.TestWidgetsFlutterBinding.ensureInitialized();
    QuickActionsPlatform.instance = MockQuickActionsPlatform();
    await setupHive();
  });
  tearDown(() async {
    await deleteHive();
  });
  test('Create Favorite', () async {
    final container = ProviderContainer(
      overrides: [],
    );
    expect(HiveProxy.getAll<FavoriteAction>(favoriteActionsBox).length, 0);
    expect(container.read(favoriteActionsProvider).length, 0);

    BaseAction? baseAction = container.read(getActionFromUUIDProvider('c53e980e-899e-4148-a13e-f57a8f9707f4'));
    expect(baseAction != null, true);
    await container.read(favoriteActionsProvider.notifier).add(baseAction!);
    expect(container.read(favoriteActionsProvider).length, 1);
    expect(container.read(favoriteActionsProvider).first.actionUUID, 'c53e980e-899e-4148-a13e-f57a8f9707f4');
    expect(HiveProxy.getAll<FavoriteAction>(favoriteActionsBox).length, 1);
    // force re-open of provider

    container.invalidate(favoriteActionsProvider);
    expect(container.read(favoriteActionsProvider).length, 1);
    expect(container.read(favoriteActionsProvider).first.actionUUID, 'c53e980e-899e-4148-a13e-f57a8f9707f4');

    expect(container.read(favoriteActionsProvider.notifier).contains(baseAction), true);
    container.read(favoriteActionsProvider).sorted();
    // remove
    await container.read(favoriteActionsProvider.notifier).remove(baseAction);
    expect(container.read(favoriteActionsProvider).length, 0);
    expect(HiveProxy.getAll<FavoriteAction>(favoriteActionsBox).length, 0);
  });
}

class MockQuickActionsPlatform extends Mock with MockPlatformInterfaceMixin implements QuickActionsPlatform {
  @override
  Future<void> clearShortcutItems() async => super.noSuchMethod(Invocation.method(#clearShortcutItems, <Object?>[]));

  @override
  Future<void> initialize(QuickActionHandler? handler) async => super.noSuchMethod(Invocation.method(#initialize, <Object?>[handler]));

  @override
  Future<void> setShortcutItems(List<ShortcutItem>? items) async => super.noSuchMethod(Invocation.method(#setShortcutItems, <Object?>[items]));
}
