import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sync_config.dart';
import '../models/sync_request.dart';
import '../models/sync_request_v2.dart';
import '../models/sync_response.dart';
import '../models/sync_response_v2.dart';
import '../models/sync_record.dart';

/// 同步API异常
class SyncApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? responseBody;

  const SyncApiException({
    this.statusCode,
    required this.message,
    this.responseBody,
  });

  @override
  String toString() => 'SyncApiException: $message';
}

/// 同步API客户端
class SyncApiClient {
  final http.Client _httpClient;

  SyncApiClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  /// 调用同步接口
  /// POST /sync
  Future<SyncResponse> sync({
    required SyncConfig config,
    required SyncRequest request,
    Duration timeout = const Duration(seconds: 120), // 同步可能较慢
  }) async {
    final uri = Uri.parse('${config.fullServerUrl}/sync');

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      ...config.customHeaders,
    };

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(request.toJson()))
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncApiException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response),
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      return SyncResponse.fromJson(json);
    } catch (e) {
      if (e is SyncApiException) rethrow;
      throw SyncApiException(message: _friendlySyncError(e, config: config));
    }
  }

  /// 调用同步接口（v2）
  /// POST /sync/v2
  Future<SyncResponseV2> syncV2({
    required SyncConfig config,
    required SyncRequestV2 request,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    final uri = Uri.parse('${config.fullServerUrl}/sync/v2');

    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      ...config.customHeaders,
    };

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(request.toJson()))
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncApiException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response),
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      return SyncResponseV2.fromJson(json);
    } catch (e) {
      if (e is SyncApiException) rethrow;
      throw SyncApiException(message: _friendlySyncError(e, config: config));
    }
  }

  String _extractErrorMessage(http.Response response) {
    try {
      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      final message = json['message'] ?? json['error'];
      if (message is String && message.trim().isNotEmpty) return message;
    } catch (_) {
      // ignore
    }
    final body = response.body;
    if (body.trim().isNotEmpty) return body;
    return '请求失败，HTTP ${response.statusCode}';
  }

  static String _decodeUtf8(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      return response.body;
    }
  }

  void dispose() {
    _httpClient.close();
  }

  /// 查询同步记录列表
  /// GET /sync/records
  Future<SyncRecordsResult> listSyncRecords({
    required SyncConfig config,
    int limit = 50,
    int? beforeId,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = Uri.parse('${config.fullServerUrl}/sync/records');
    final query = <String, String>{
      'user_id': config.userId,
      'limit': limit.toString(),
      if (beforeId != null) 'before_id': beforeId.toString(),
    };
    final uri = base.replace(queryParameters: query);

    final headers = <String, String>{...config.customHeaders};

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncApiException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response),
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        throw SyncApiException(message: json['message'] as String? ?? '查询失败');
      }

      final recordsRaw = (json['records'] as List?) ?? const [];
      final records = recordsRaw
          .whereType<Map>()
          .map((e) => SyncRecord.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      final nextBeforeId = json['next_before_id'];
      final next = nextBeforeId == null
          ? null
          : (nextBeforeId is int
                ? nextBeforeId
                : int.tryParse(nextBeforeId.toString()));

      return SyncRecordsResult(records: records, nextBeforeId: next);
    } catch (e) {
      if (e is SyncApiException) rethrow;
      throw SyncApiException(message: _friendlyQueryError(e, config: config));
    }
  }

  /// 查询单条同步记录详情
  /// GET /sync/records/{id}
  Future<SyncRecord> getSyncRecord({
    required SyncConfig config,
    required int id,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = Uri.parse('${config.fullServerUrl}/sync/records/$id');
    final uri = base.replace(queryParameters: {'user_id': config.userId});

    final headers = <String, String>{...config.customHeaders};

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncApiException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response),
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        throw SyncApiException(message: json['message'] as String? ?? '查询失败');
      }

      final recordRaw = json['record'];
      if (recordRaw is! Map) {
        throw SyncApiException(message: '响应格式错误：缺少 record');
      }
      return SyncRecord.fromJson(Map<String, dynamic>.from(recordRaw));
    } catch (e) {
      if (e is SyncApiException) rethrow;
      throw SyncApiException(message: _friendlyQueryError(e, config: config));
    }
  }

  /// 查询某个服务端历史快照（用于回退/排查）
  /// GET /sync/snapshots/{revision}
  Future<SyncSnapshot> getSnapshotByRevision({
    required SyncConfig config,
    required int revision,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final base = Uri.parse('${config.fullServerUrl}/sync/snapshots/$revision');
    final uri = base.replace(queryParameters: {'user_id': config.userId});

    final headers = <String, String>{...config.customHeaders};

    try {
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncApiException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response),
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        throw SyncApiException(message: json['message'] as String? ?? '查询失败');
      }

      final raw = json['snapshot'];
      if (raw is! Map) {
        throw SyncApiException(message: '响应格式错误：缺少 snapshot');
      }
      return SyncSnapshot.fromJson(Map<String, dynamic>.from(raw));
    } catch (e) {
      if (e is SyncApiException) rethrow;
      throw SyncApiException(message: _friendlyQueryError(e, config: config));
    }
  }

  /// 服务端回退到历史版本，并返回回退后的快照（推荐：回退后立即覆盖本地）
  /// POST /sync/rollback
  Future<SyncRollbackResult> rollbackToRevision({
    required SyncConfig config,
    required int targetRevision,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final uri = Uri.parse('${config.fullServerUrl}/sync/rollback');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
      ...config.customHeaders,
    };

    final body = jsonEncode({
      'user_id': config.userId,
      'target_revision': targetRevision,
    });

    try {
      final response = await _httpClient
          .post(uri, headers: headers, body: body)
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw SyncApiException(
          statusCode: response.statusCode,
          message: _extractErrorMessage(response),
          responseBody: response.body,
        );
      }

      final json = jsonDecode(_decodeUtf8(response)) as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      if (!success) {
        throw SyncApiException(message: json['message'] as String? ?? '回退失败');
      }
      return SyncRollbackResult.fromJson(json);
    } catch (e) {
      if (e is SyncApiException) rethrow;
      throw SyncApiException(message: _friendlySyncError(e, config: config));
    }
  }

  static String _friendlySyncError(Object e, {required SyncConfig config}) {
    final text = e.toString();
    if (_looksLikeTlsWrongVersion(text)) {
      return [
        '同步请求失败：TLS/HTTPS 握手失败（可能把 HTTP 服务当成 HTTPS 访问）',
        '当前服务端地址：${config.fullServerUrl}',
        '建议：在“服务器地址”中显式填写 http://（例如 http://127.0.0.1），或确认服务端已启用 HTTPS。',
      ].join('\n');
    }
    return '同步请求失败: $e';
  }

  static String _friendlyQueryError(Object e, {required SyncConfig config}) {
    final text = e.toString();
    if (_looksLikeTlsWrongVersion(text)) {
      return [
        '请求失败：TLS/HTTPS 握手失败（可能把 HTTP 服务当成 HTTPS 访问）',
        '当前服务端地址：${config.fullServerUrl}',
        '建议：在“服务器地址”中显式填写 http://（例如 http://127.0.0.1），或确认服务端已启用 HTTPS。',
      ].join('\n');
    }
    return '查询失败: $e';
  }

  static bool _looksLikeTlsWrongVersion(String text) {
    final lower = text.toLowerCase();
    return lower.contains('handshakeexception') ||
        lower.contains('wrong_version_number');
  }

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static Map<String, Map<String, dynamic>> _readToolsData(dynamic value) {
    if (value is! Map) return const <String, Map<String, dynamic>>{};
    final result = <String, Map<String, dynamic>>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final val = entry.value;
      if (key is String && val is Map) {
        result[key] = Map<String, dynamic>.from(val);
      }
    }
    return result;
  }
}

class SyncRecordsResult {
  final List<SyncRecord> records;
  final int? nextBeforeId;

  const SyncRecordsResult({required this.records, required this.nextBeforeId});
}

class SyncSnapshot {
  final String userId;
  final int serverRevision;
  final int updatedAtMs;
  final Map<String, Map<String, dynamic>> toolsData;

  const SyncSnapshot({
    required this.userId,
    required this.serverRevision,
    required this.updatedAtMs,
    required this.toolsData,
  });

  factory SyncSnapshot.fromJson(Map<String, dynamic> json) {
    return SyncSnapshot(
      userId: (json['user_id'] as String?) ?? '',
      serverRevision: SyncApiClient._readInt(
        json['server_revision'],
        fallback: 0,
      ),
      updatedAtMs: SyncApiClient._readInt(json['updated_at_ms'], fallback: 0),
      toolsData: SyncApiClient._readToolsData(json['tools_data']),
    );
  }
}

class SyncRollbackResult {
  final DateTime serverTime;
  final int serverRevision;
  final int restoredFromRevision;
  final Map<String, Map<String, dynamic>> toolsData;

  const SyncRollbackResult({
    required this.serverTime,
    required this.serverRevision,
    required this.restoredFromRevision,
    required this.toolsData,
  });

  factory SyncRollbackResult.fromJson(Map<String, dynamic> json) {
    final serverTimeMs = SyncApiClient._readInt(
      json['server_time'],
      fallback: 0,
    );
    return SyncRollbackResult(
      serverTime: DateTime.fromMillisecondsSinceEpoch(serverTimeMs),
      serverRevision: SyncApiClient._readInt(
        json['server_revision'],
        fallback: 0,
      ),
      restoredFromRevision: SyncApiClient._readInt(
        json['restored_from_revision'],
        fallback: 0,
      ),
      toolsData: SyncApiClient._readToolsData(json['tools_data']),
    );
  }
}
