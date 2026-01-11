/// 同步响应数据结构
class SyncResponse {
  final bool success;
  final String? message;
  final Map<String, Map<String, dynamic>>? toolsData; // 服务端返回的数据
  final DateTime serverTime;

  const SyncResponse({
    required this.success,
    this.message,
    this.toolsData,
    required this.serverTime,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      success: json['success'] as bool,
      message: json['message'] as String?,
      toolsData: json['tools_data'] != null
          ? Map<String, Map<String, dynamic>>.from(
              (json['tools_data'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
              ),
            )
          : null,
      serverTime: DateTime.fromMillisecondsSinceEpoch(
        json['server_time'] as int,
      ),
    );
  }
}
