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
      throw SyncApiException(message: '同步请求失败: $e');
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
      throw SyncApiException(message: '同步请求失败: $e');
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
      throw SyncApiException(message: '查询同步记录失败: $e');
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
      throw SyncApiException(message: '查询同步记录失败: $e');
    }
  }
}

class SyncRecordsResult {
  final List<SyncRecord> records;
  final int? nextBeforeId;

  const SyncRecordsResult({required this.records, required this.nextBeforeId});
}
