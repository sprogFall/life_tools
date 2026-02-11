import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../sync/services/app_config_updated_at.dart';
import '../utils/dev_log.dart';
import 'ai_call_history_record.dart';
import 'ai_call_source.dart';

class AiCallHistoryService extends ChangeNotifier {
  static const _recordsKey = 'ai_call_history_records_v1';
  static const _retentionLimitKey = 'ai_call_history_retention_limit_v1';

  static const defaultRetentionLimit = 5;
  static const retentionLimitOptions = <int>[5, 10, 20];

  SharedPreferences? _prefs;
  int _retentionLimit = defaultRetentionLimit;
  List<AiCallHistoryRecord> _records = [];

  int get retentionLimit => _retentionLimit;
  UnmodifiableListView<AiCallHistoryRecord> get records =>
      UnmodifiableListView(_records);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final rawLimit = _prefs?.getInt(_retentionLimitKey);
    _retentionLimit = _normalizeRetentionLimit(rawLimit);

    final rawRecords = _prefs?.getString(_recordsKey);
    _records = _decodeRecordsFromDynamic(rawRecords);
    _trimLocalRecords();
    await _persist(touchUpdatedAt: false);
  }

  Map<String, dynamic> exportAsMap() {
    return <String, dynamic>{
      'retention_limit': _retentionLimit,
      'records': _records.map((e) => e.toMap()).toList(growable: false),
    };
  }

  Future<void> restoreFromMap(Map<String, dynamic> map) async {
    final hasRetentionLimit = map.containsKey('retention_limit');
    final hasRecords = map.containsKey('records');
    if (!hasRetentionLimit && !hasRecords) {
      return;
    }

    final nextRetentionLimit = hasRetentionLimit
        ? _normalizeRetentionLimit((map['retention_limit'] as num?)?.toInt())
        : _retentionLimit;

    final nextRecords = hasRecords
        ? _decodeRecordsFromDynamic(map['records'])
        : _records;

    _retentionLimit = nextRetentionLimit;
    _records = nextRecords;
    _trimLocalRecords();
    await _persist();
    notifyListeners();
  }

  Future<void> addRecord({
    required AiCallSource source,
    required String model,
    required String prompt,
    required String response,
    DateTime? createdAt,
  }) async {
    final record = AiCallHistoryRecord(
      id: '${DateTime.now().microsecondsSinceEpoch}_${_records.length + 1}',
      source: source,
      model: model.trim(),
      prompt: prompt,
      response: response,
      createdAt: createdAt ?? DateTime.now(),
    );

    _records = [record, ..._records]
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) {
          return byTime;
        }
        return b.id.compareTo(a.id);
      });

    _trimLocalRecords();
    await _persist();
    notifyListeners();
  }

  Future<void> updateRetentionLimit(int limit) async {
    final normalized = _normalizeRetentionLimit(limit);
    if (normalized == _retentionLimit) {
      return;
    }

    _retentionLimit = normalized;
    _trimLocalRecords();
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    _records = [];
    await _persist();
    notifyListeners();
  }

  List<AiCallHistoryRecord> _decodeRecordsFromDynamic(dynamic raw) {
    dynamic decoded = raw;

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) {
        return [];
      }
      try {
        decoded = jsonDecode(text);
      } catch (error, stackTrace) {
        devLog(
          '解析 AI 历史记录失败',
          name: 'ai_call_history',
          error: error,
          stackTrace: stackTrace,
        );
        return [];
      }
    }

    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((e) => AiCallHistoryRecord.fromMap(e.cast<String, dynamic>()))
        .toList(growable: false)
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) {
          return byTime;
        }
        return b.id.compareTo(a.id);
      });
  }

  void _trimLocalRecords() {
    if (_records.length <= _retentionLimit) {
      return;
    }
    _records = _records.take(_retentionLimit).toList(growable: false);
  }

  int _normalizeRetentionLimit(int? limit) {
    if (retentionLimitOptions.contains(limit)) {
      return limit!;
    }
    return defaultRetentionLimit;
  }

  Future<void> _persist({bool touchUpdatedAt = true}) async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }

    await prefs.setInt(_retentionLimitKey, _retentionLimit);
    await prefs.setString(
      _recordsKey,
      jsonEncode(_records.map((e) => e.toMap()).toList(growable: false)),
    );

    if (touchUpdatedAt) {
      await AppConfigUpdatedAt.touch(prefs);
    }
  }
}
