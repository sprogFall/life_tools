import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _records = _decodeRecords(rawRecords);
    _trimLocalRecords();
    await _persist();
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

  List<AiCallHistoryRecord> _decodeRecords(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
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

  Future<void> _persist() async {
    await _prefs?.setInt(_retentionLimitKey, _retentionLimit);
    await _prefs?.setString(
      _recordsKey,
      jsonEncode(_records.map((e) => e.toMap()).toList(growable: false)),
    );
  }
}
