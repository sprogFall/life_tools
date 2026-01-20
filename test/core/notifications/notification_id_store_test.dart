import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/notifications/notification_id_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NotificationIdStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('reserve 会递增并在重启后延续', () async {
      final store1 = await NotificationIdStore.open();
      expect(await store1.reserve(), 1);
      expect(await store1.reserve(), 2);

      final store2 = await NotificationIdStore.open();
      expect(await store2.reserve(), 3);
    });

    test('会对越界 nextId 做归一化', () async {
      SharedPreferences.setMockInitialValues({'local_notification_next_id': 0});
      final store = await NotificationIdStore.open(minId: 1, maxId: 10);
      expect(store.peekNextId(), 1);
      expect(await store.reserve(), 1);
    });

    test('到达上限后会回绕到 minId', () async {
      SharedPreferences.setMockInitialValues({'local_notification_next_id': 10});
      final store = await NotificationIdStore.open(minId: 1, maxId: 10);
      expect(await store.reserve(), 10);
      expect(await store.reserve(), 1);
    });
  });
}

