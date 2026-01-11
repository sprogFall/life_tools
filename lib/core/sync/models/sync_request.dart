/// 同步请求数据结构
class SyncRequest {
  final String userId;
  final Map<String, Map<String, dynamic>> toolsData; // key: toolId, value: 工具数据

  const SyncRequest({
    required this.userId,
    required this.toolsData,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'tools_data': toolsData,
      };
}
