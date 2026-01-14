import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sync_config.dart';
import '../models/sync_request.dart';
import '../models/sync_response.dart';

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
}
