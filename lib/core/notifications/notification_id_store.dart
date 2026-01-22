import 'package:shared_preferences/shared_preferences.dart';

class NotificationIdStore {
  static const String _keyNextId = 'local_notification_next_id';

  final SharedPreferences _prefs;
  final int _minId;
  final int _maxId;
  int _nextId;

  NotificationIdStore._({
    required SharedPreferences prefs,
    required int minId,
    required int maxId,
    required int nextId,
  }) : _prefs = prefs,
       _minId = minId,
       _maxId = maxId,
       _nextId = nextId;

  static Future<NotificationIdStore> open({
    SharedPreferences? prefs,
    int minId = 1,
    int maxId = 999999,
  }) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final stored = p.getInt(_keyNextId);
    final normalized = stored == null || stored < minId || stored > maxId
        ? minId
        : stored;
    if (stored != normalized) {
      await p.setInt(_keyNextId, normalized);
    }

    return NotificationIdStore._(
      prefs: p,
      minId: minId,
      maxId: maxId,
      nextId: normalized,
    );
  }

  Future<int> reserve() async {
    final id = _nextId;
    _nextId = _nextId >= _maxId ? _minId : _nextId + 1;
    await _prefs.setInt(_keyNextId, _nextId);
    return id;
  }

  int peekNextId() => _nextId;
}
