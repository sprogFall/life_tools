// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '小蜜';

  @override
  String get common_confirm => '确认';

  @override
  String get common_cancel => '取消';

  @override
  String get common_delete => '删除';

  @override
  String get common_save => '保存';

  @override
  String get common_loading => '加载中...';

  @override
  String get common_copy => '复制';

  @override
  String get common_yes => '是';

  @override
  String get common_no => '否';

  @override
  String get common_public => '公有';

  @override
  String get common_private => '私有';

  @override
  String get common_home => '首页';

  @override
  String get common_tasks => '任务';

  @override
  String get common_calendar => '日历';

  @override
  String get tool_management_title => '工具管理';

  @override
  String tool_management_hint_content(Object hiddenCount) {
    return '首页长按工具卡片并拖拽可调整顺序。\\n这里可设置启动默认进入工具，并选择是否在首页显示（已隐藏 $hiddenCount 个）。';
  }

  @override
  String get tool_management_default_tool_title => '启动默认进入';

  @override
  String get tool_management_default_tool_subtitle => '设置后，下次打开应用将直接进入该工具';

  @override
  String get tool_management_home_visibility_title => '首页显示';

  @override
  String get tool_management_home_visibility_subtitle =>
      '关闭后首页不显示该工具（不影响备份与默认进入）';

  @override
  String get tool_stockpile_name => '囤货助手';

  @override
  String get tool_overcooked_name => '胡闹厨房';

  @override
  String get tool_work_log_name => '工作记录';

  @override
  String get work_log_ai_entry => 'AI录入';

  @override
  String get sync_user_mismatch_title => '同步用户不匹配';

  @override
  String sync_user_mismatch_content(Object localUserId, Object serverUserId) {
    return '检测到本地数据属于“$localUserId”，但当前同步用户为“$serverUserId”。继续同步可能会覆盖其中一端的数据，请选择处理方式。';
  }

  @override
  String get sync_user_mismatch_overwrite_local => '覆盖本地（使用服务端）';

  @override
  String get sync_user_mismatch_overwrite_server => '覆盖服务端（使用本地）';

  @override
  String get common_refresh => '刷新';

  @override
  String get common_export => '导出';

  @override
  String get common_restore => '还原';

  @override
  String get common_clear => '清空';

  @override
  String get common_add => '添加';

  @override
  String get common_continue => '继续';

  @override
  String get common_load_more => '加载更多';

  @override
  String get common_not_configured => '未配置';

  @override
  String get common_go_settings => '去设置';

  @override
  String get network_status_wifi => 'WiFi';

  @override
  String get network_status_mobile => '移动网络';

  @override
  String get network_status_offline => '离线';

  @override
  String get network_status_unknown => '未知';

  @override
  String get backup_restore_title => '备份与还原';

  @override
  String get backup_received_title => '已接收备份文件';

  @override
  String get backup_received_content => '备份内容已填入，请检查后点击“开始还原”按钮。';

  @override
  String get backup_export_hint_intro => '将以下内容导出为 JSON（大数据量推荐导出为 TXT 文件）：';

  @override
  String get backup_export_hint_items =>
      '1) AI 配置（接口地址 / 模型 / 参数）\\n2) 数据同步配置（服务器/网络模式等）\\n3) 资源存储配置（七牛/本地）\\n4) 工具管理（默认进入/首页显示/工具排序等应用配置）\\n5) 各工具数据（通过 ToolSyncProvider 导出）';

  @override
  String get backup_include_sensitive_label => '包含敏感信息（AI 密钥 / 同步令牌 / 存储密钥）';

  @override
  String get backup_include_sensitive_on_hint =>
      '默认已开启：导出内容会包含密钥/令牌，分享前请确认接收方可信。';

  @override
  String get backup_include_sensitive_off_hint =>
      '已关闭：不导出密钥/令牌（更安全，导入后可在设置页重新填写）。';

  @override
  String get backup_export_share_button => '导出并分享';

  @override
  String get backup_export_save_txt_button => '保存为 TXT 文件';

  @override
  String get backup_export_copy_clipboard_button => '导出 JSON 到剪切板';

  @override
  String get backup_restore_hint => '粘贴 JSON 并覆盖写入本地（请谨慎操作，建议先导出备份）。';

  @override
  String get backup_restore_placeholder => '在此粘贴备份 JSON…';

  @override
  String get backup_restore_paste_button => '从剪切板粘贴';

  @override
  String get backup_restore_import_txt_button => '从 TXT 文件导入';

  @override
  String get backup_restore_start_button => '开始还原（覆盖本地）';

  @override
  String get backup_share_success_title => '分享成功';

  @override
  String get backup_share_success_content => '备份文件已分享';

  @override
  String get backup_share_failed_title => '分享失败';

  @override
  String get backup_exported_title => '已导出';

  @override
  String backup_exported_saved_content(Object path, Object kb) {
    return '已保存到：\\n$path\\n\\n内容为紧凑 JSON（约 $kb KB）';
  }

  @override
  String get backup_export_failed_title => '导出失败';

  @override
  String backup_exported_copied_content(Object kb) {
    return '紧凑 JSON 已复制到剪切板（约 $kb KB）';
  }

  @override
  String get backup_file_picker_title => '选择备份 TXT 文件';

  @override
  String get backup_import_failed_title => '导入失败';

  @override
  String backup_restore_summary_imported(Object count) {
    return '已导入工具：$count';
  }

  @override
  String backup_restore_summary_skipped(Object count) {
    return '已跳过工具：$count';
  }

  @override
  String backup_restore_summary_failed(Object tools) {
    return '失败工具：$tools';
  }

  @override
  String get backup_restore_complete_title => '还原完成';

  @override
  String get backup_restore_failed_title => '还原失败';

  @override
  String get backup_confirm_restore_title => '确认还原？';

  @override
  String get backup_confirm_restore_content => '该操作会覆盖本地配置与数据，建议先导出备份。';

  @override
  String get sync_settings_title => '数据同步';

  @override
  String get sync_network_type_section_title => '网络类型';

  @override
  String get sync_network_public_label => '公网模式';

  @override
  String get sync_network_private_label => '私网模式';

  @override
  String get sync_network_public_hint => '公网模式：只要有网络即可同步';

  @override
  String get sync_network_private_hint => '私网模式：仅允许在指定 WiFi 下同步（用于家庭/公司内网）';

  @override
  String get sync_basic_section_title => '基本配置';

  @override
  String get sync_user_id_label => '用户 ID';

  @override
  String get sync_user_id_placeholder => '用于服务端区分用户';

  @override
  String get sync_server_url_label => '服务器地址';

  @override
  String get sync_server_url_placeholder =>
      '例如 https://sync.example.com 或 http://127.0.0.1';

  @override
  String get sync_port_label => '端口';

  @override
  String get sync_port_placeholder => '默认 443';

  @override
  String get sync_server_url_tip =>
      '提示：本地部署（docker/uvicorn）通常是 http + 8080，请显式填写 http:// 避免 TLS 握手错误。';

  @override
  String get sync_allowed_wifi_section_title => '允许的 WiFi（SSID）';

  @override
  String sync_current_wifi_label(Object ssid) {
    return '当前 WiFi：$ssid';
  }

  @override
  String get sync_current_wifi_unknown_hint => '当前 WiFi：未知（可点右侧刷新）';

  @override
  String get sync_allowed_wifi_empty_hint => '未配置允许的 WiFi 名称';

  @override
  String get sync_wifi_ssid_tip => '提示：SSID 区分大小写，建议不要包含引号和首尾空格';

  @override
  String get sync_advanced_section_title => '高级选项';

  @override
  String get sync_auto_sync_on_startup_label => '启动时自动同步';

  @override
  String get sync_section_title => '同步';

  @override
  String get sync_now_button => '立即同步';

  @override
  String sync_last_sync_label(Object time) {
    return '上次同步：$time';
  }

  @override
  String get sync_last_sync_none => '上次同步：暂无';

  @override
  String get sync_success_label => '同步成功';

  @override
  String get sync_error_details_label => '错误详情：';

  @override
  String get sync_copy_error_details_button => '复制错误详情';

  @override
  String sync_current_network_hint(Object network) {
    return '当前网络：$network（私网模式需 WiFi）';
  }

  @override
  String get sync_wifi_permission_hint =>
      '无法获取 SSID：未获得定位权限（Android 读取 WiFi 名称需要定位权限）';

  @override
  String get sync_wifi_ssid_unavailable_hint =>
      '已连接 WiFi，但无法获取 SSID（可能缺少定位权限/未开启定位/系统限制）';

  @override
  String get sync_location_permission_required_title => '需要定位权限';

  @override
  String get sync_location_permission_required_content =>
      'Android 读取当前 WiFi 名称（SSID）需要定位权限，请在系统弹窗中选择允许后再重试。';

  @override
  String get sync_permission_permanently_denied_title => '权限被永久拒绝';

  @override
  String get sync_permission_permanently_denied_content =>
      '请前往系统设置开启定位权限后再获取 WiFi 名称。';

  @override
  String get sync_config_invalid_title => '提示';

  @override
  String get sync_config_invalid_content => '配置不完整，请检查必填项（私网模式需至少配置 1 个 WiFi）';

  @override
  String get sync_config_saved_title => '已保存';

  @override
  String get sync_config_saved_content => '同步配置已更新';

  @override
  String get sync_finished_title_success => '同步完成';

  @override
  String get sync_finished_title_failed => '同步失败';

  @override
  String get sync_finished_content_success => '已完成同步';

  @override
  String get sync_finished_content_failed => '请查看页面内的错误详情';

  @override
  String get sync_add_wifi_title => '添加 WiFi 名称（SSID）';

  @override
  String get sync_add_wifi_placeholder => '例如 MyHomeWifi';

  @override
  String get sync_records_title => '同步记录';

  @override
  String get sync_details_title => '同步详情';

  @override
  String get sync_records_config_missing_error => '同步配置未设置或不完整，请先完成配置后再查看同步记录。';

  @override
  String get sync_details_config_missing_error => '同步配置未设置或不完整，请先完成配置后再查看同步详情。';

  @override
  String get sync_server_label => '服务端';

  @override
  String sync_user_label(Object userId) {
    return '用户：$userId';
  }

  @override
  String get sync_open_settings_button => '同步设置';

  @override
  String get sync_go_config_button => '去配置数据同步';

  @override
  String get sync_records_empty_hint => '暂无同步记录（仅记录发生“客户端更新/服务端更新/回退”的同步行为）';

  @override
  String get sync_direction_client_to_server => '客户端 → 服务端';

  @override
  String get sync_direction_server_to_client => '服务端 → 客户端';

  @override
  String get sync_direction_rollback => '服务端回退';

  @override
  String get sync_direction_unknown => '未知操作';

  @override
  String sync_summary_changed_tools(Object count) {
    return '变更工具 $count';
  }

  @override
  String sync_summary_changed_items(Object count, Object plus) {
    return '变更项 $count$plus';
  }

  @override
  String get sync_summary_no_major_changes => '无主要变更';

  @override
  String get sync_action_client_updates_server => '客户端更新服务端';

  @override
  String get sync_action_server_updates_client => '服务端更新客户端';

  @override
  String get sync_action_rollback_server => '回退（服务端）';

  @override
  String get sync_action_unknown => '未知';

  @override
  String sync_details_time_label(Object time) {
    return '时间：$time';
  }

  @override
  String sync_details_client_updated_at_label(Object ms) {
    return '客户端更新时间：$ms';
  }

  @override
  String sync_details_server_updated_at_label(Object before, Object after) {
    return '服务端更新时间：$before → $after';
  }

  @override
  String sync_details_server_revision_label(Object before, Object after) {
    return '服务端游标：$before → $after';
  }

  @override
  String get sync_rollback_section_title => '版本恢复';

  @override
  String get sync_rollback_section_hint => '您可以将数据恢复到此同步记录之前的状态。';

  @override
  String get sync_rollback_to_version_title => '恢复到此版本';

  @override
  String get sync_rollback_to_version_subtitle => '云端和本地都将回退';

  @override
  String get sync_rollback_local_only_title => '仅恢复本地';

  @override
  String get sync_rollback_local_only_subtitle => '仅本地预览，不影响云端';

  @override
  String sync_rollback_target_revision(Object revision) {
    return '版本号 $revision';
  }

  @override
  String get sync_rollback_no_target => '无可恢复版本';

  @override
  String get sync_not_configured_title => '同步未配置';

  @override
  String get sync_not_configured_content => '请先完成服务器地址/端口与用户标识配置，然后再进行回退操作。';

  @override
  String get sync_network_precheck_failed_title => '网络预检失败';

  @override
  String get sync_confirm_rollback_server_title => '确认回退服务端？';

  @override
  String sync_confirm_rollback_server_content(Object revision) {
    return '将服务端回退到 $revision，并覆盖本地数据。该操作会产生新的服务端版本。';
  }

  @override
  String get sync_confirm_rollback_server_confirm => '回退';

  @override
  String get sync_rollback_done_title => '回退完成';

  @override
  String sync_rollback_done_content(Object revision, Object newRevision) {
    return '已回退到 $revision，并覆盖本地。新的服务端版本：$newRevision';
  }

  @override
  String sync_rollback_done_partial_content(Object error) {
    return '服务端已回退，但部分工具导入失败：\\n$error';
  }

  @override
  String get sync_rollback_failed_title => '回退失败';

  @override
  String get sync_confirm_rollback_local_title => '确认仅回退本地？';

  @override
  String sync_confirm_rollback_local_content(Object revision) {
    return '将本地数据覆盖为服务端历史版本 $revision，但不会修改服务端当前版本。\\n注意：下次同步时本地可能被服务端覆盖（建议改用“回退服务端并覆盖本地”）。';
  }

  @override
  String get sync_confirm_rollback_local_confirm => '覆盖本地';

  @override
  String get sync_overwrite_local_done_title => '已覆盖本地';

  @override
  String sync_overwrite_local_done_content(Object revision) {
    return '本地已覆盖为 $revision';
  }

  @override
  String sync_overwrite_local_done_partial_content(Object error) {
    return '部分工具导入失败：\\n$error';
  }

  @override
  String get sync_overwrite_local_failed_title => '覆盖失败';

  @override
  String get sync_diff_none => '无差异详情';

  @override
  String get sync_diff_format_error => '差异数据格式错误';

  @override
  String get sync_diff_no_substantive => '无实质性数据变更（仅包含被忽略的长度变化）';

  @override
  String get sync_diff_unknown_item => '• 未知差异项';

  @override
  String get tool_tag_manager_name => '标签管理';

  @override
  String get tool_app_config_name => '应用配置';

  @override
  String get tag_category_location => '位置';

  @override
  String get tag_category_item_type => '物品类型';

  @override
  String get tag_category_dish_type => '菜品类型';

  @override
  String get tag_category_ingredient => '食材';

  @override
  String get tag_category_sauce => '酱料';

  @override
  String get tag_category_affiliation => '归属';

  @override
  String get tag_category_flavor => '风味';

  @override
  String get tag_category_meal_slot => '餐次';

  @override
  String get sync_diff_label_added => '新增';

  @override
  String get sync_diff_label_removed => '删除';

  @override
  String get sync_diff_label_modified => '修改';

  @override
  String get sync_diff_label_type_changed => '类型变更';

  @override
  String get sync_diff_content_changed => '内容已变更';

  @override
  String get sync_diff_added_data => '新增了数据';

  @override
  String get sync_diff_removed_data => '删除了数据';

  @override
  String sync_diff_detail_tag_added(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return '新增了$toolName下$categoryName类型的标签：【$tagName】';
  }

  @override
  String sync_diff_detail_tag_removed(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return '删除了$toolName下$categoryName类型的标签：【$tagName】';
  }

  @override
  String sync_diff_detail_named_added(Object name) {
    return '新增了：【$name】';
  }

  @override
  String sync_diff_detail_named_removed(Object name) {
    return '删除了：【$name】';
  }

  @override
  String sync_diff_detail_titled_added(Object title) {
    return '新增了：【$title】';
  }

  @override
  String sync_diff_detail_titled_removed(Object title) {
    return '删除了：【$title】';
  }

  @override
  String sync_diff_path_item(Object index) {
    return '第$index项';
  }

  @override
  String get sync_auto_sync_success_toast => '自动同步成功';

  @override
  String sync_auto_sync_failed_toast(Object error) {
    return '自动同步失败: $error';
  }

  @override
  String get ai_settings_title => 'AI配置';

  @override
  String get ai_settings_openai_section_title => 'OpenAI 兼容配置';

  @override
  String get ai_settings_base_url_label => '接口地址（Base URL）';

  @override
  String get ai_settings_base_url_placeholder => 'https://api.openai.com/v1';

  @override
  String get ai_settings_api_key_label => 'API 密钥（Key）';

  @override
  String get ai_settings_api_key_placeholder => 'sk-...';

  @override
  String get ai_settings_model_label => '模型（Model）';

  @override
  String get ai_settings_model_placeholder => 'gpt-4o-mini';

  @override
  String get ai_settings_temperature_label => '温度（Temperature）';

  @override
  String get ai_settings_temperature_placeholder => '0.7';

  @override
  String get ai_settings_max_tokens_label => '最大输出（Max Tokens）';

  @override
  String get ai_settings_max_tokens_placeholder => '1024';

  @override
  String get ai_settings_test_button => '测试连接';

  @override
  String get ai_settings_testing_button => '测试中...';

  @override
  String get ai_settings_tips_section_title => '说明';

  @override
  String get ai_settings_tips_content =>
      '1. 接口地址支持填写到域名（如 https://example.com），也可直接填写到 /v1。\\n2. 当前使用 OpenAI 兼容接口：/v1/chat/completions。\\n3. API 密钥将保存在本机（SharedPreferences）。';

  @override
  String get ai_settings_danger_section_title => '危险区';

  @override
  String get ai_settings_clear_button => '清除AI配置';

  @override
  String get ai_settings_invalid_title => '提示';

  @override
  String get ai_settings_invalid_content =>
      '请检查配置项：接口地址 / API 密钥 / 模型不能为空；温度范围 0~2；最大输出 > 0。';

  @override
  String get ai_settings_saved_title => '已保存';

  @override
  String ai_settings_saved_content(Object model) {
    return '当前模型：$model';
  }

  @override
  String get ai_settings_test_invalid_content => '请先填写合法的 AI 配置，再进行测试。';

  @override
  String get ai_settings_testing_loading_title => '测试中';

  @override
  String get ai_settings_test_result_title => '测试结果';

  @override
  String get ai_settings_test_failed_title => '测试失败';

  @override
  String get ai_settings_clear_confirm_title => '确认清除？';

  @override
  String get ai_settings_clear_confirm_content => '清除后将无法使用 AI 相关功能，直到重新配置。';

  @override
  String get ai_settings_clear_confirm_button => '清除';

  @override
  String get obj_store_settings_title => '资源存储';

  @override
  String get obj_store_settings_type_section_title => '存储方式';

  @override
  String get obj_store_settings_type_none_label => '未选择';

  @override
  String get obj_store_settings_type_local_label => '本地存储';

  @override
  String get obj_store_settings_type_qiniu_label => '七牛云';

  @override
  String get obj_store_settings_type_data_capsule_label => '数据胶囊';

  @override
  String get obj_store_settings_qiniu_section_title => '七牛云配置';

  @override
  String get obj_store_settings_data_capsule_section_title => '数据胶囊配置';

  @override
  String get obj_store_settings_test_section_title => '测试';

  @override
  String get obj_store_settings_tips_section_title => '说明';

  @override
  String get obj_store_settings_danger_section_title => '危险区';

  @override
  String get obj_store_settings_clear_button => '清除资源存储配置';

  @override
  String get obj_store_settings_bucket_type_label => '空间类型';

  @override
  String get obj_store_settings_protocol_label => '访问协议';

  @override
  String get obj_store_settings_protocol_https_label => 'https';

  @override
  String get obj_store_settings_protocol_http_label => 'http';

  @override
  String get obj_store_settings_http_security_warning =>
      '安全提示：HTTP 为明文传输，访问密钥/文件内容可能被截获，仅建议内网调试使用。';

  @override
  String get obj_store_settings_access_key_label => 'AccessKey（访问密钥）';

  @override
  String get obj_store_settings_secret_key_label => 'SecretKey（私密密钥）';

  @override
  String get obj_store_settings_access_key_ak_label => 'AccessKey（AK）';

  @override
  String get obj_store_settings_secret_key_sk_label => 'SecretKey（SK）';

  @override
  String get obj_store_settings_bucket_label => 'Bucket';

  @override
  String get obj_store_settings_domain_label => '访问域名（用于拼接图片URL）';

  @override
  String get obj_store_settings_upload_host_label => '上传域名（可选）';

  @override
  String get obj_store_settings_key_prefix_label => 'Key 前缀（可选）';

  @override
  String get obj_store_settings_endpoint_label => 'Endpoint（上传/访问）';

  @override
  String get obj_store_settings_domain_optional_label => '访问域名（可选）';

  @override
  String get obj_store_settings_region_label => 'Region';

  @override
  String get obj_store_settings_url_style_label => 'URL 风格';

  @override
  String get obj_store_settings_fixed_private_value => '私有（固定）';

  @override
  String get obj_store_settings_fixed_https_value => 'https（固定）';

  @override
  String get obj_store_settings_fixed_path_style_value => '路径风格（固定）';

  @override
  String obj_store_settings_fixed_region_value(Object region) {
    return '$region（固定）';
  }

  @override
  String get obj_store_settings_placeholder_example_short => '如：xxxxx';

  @override
  String get obj_store_settings_placeholder_bucket => '如：my-bucket';

  @override
  String get obj_store_settings_placeholder_domain => '如：cdn.example.com';

  @override
  String get obj_store_settings_placeholder_upload_host =>
      '默认：https://upload.qiniup.com';

  @override
  String get obj_store_settings_placeholder_endpoint => '如：s3.example.com';

  @override
  String get obj_store_settings_placeholder_key_prefix => '如：media/';

  @override
  String get obj_store_settings_placeholder_query => '如：media/xxx.png';

  @override
  String get obj_store_settings_test_file_not_selected => '未选择文件';

  @override
  String obj_store_settings_test_file_selected(Object name, Object bytes) {
    return '$name（$bytes bytes）';
  }

  @override
  String get obj_store_settings_choose_file_button => '选择文件';

  @override
  String get obj_store_settings_test_upload_button => '测试上传';

  @override
  String get obj_store_settings_test_uploading_button => '测试上传中...';

  @override
  String get obj_store_settings_test_query_button => '测试查询';

  @override
  String get obj_store_settings_test_querying_button => '查询中...';

  @override
  String obj_store_settings_test_upload_result(Object key, Object uri) {
    return '上传结果：\\nKey: $key\\nURI: $uri';
  }

  @override
  String get obj_store_settings_query_key_label =>
      '查询 Key / URL（用于测试查询/拼接URL，支持粘贴完整 URL）';

  @override
  String get obj_store_settings_tips_content =>
      '1. 本地存储会将文件写入应用私有目录（卸载应用后会被清理）。\\n2. 七牛云存储会在本机生成上传凭证并直接上传到七牛。\\n3. 七牛私有空间查询会生成带签名的临时下载链接。\\n4. 数据胶囊为私有空间，查询会生成带签名的临时链接（默认 30 分钟）。\\n5. 访问密钥属于敏感信息，仅建议自用场景配置；如需更安全的方案，建议使用服务端下发的上传凭证。\\n6. 如配置了自定义访问域名，请确保与服务端配置一致，避免出现“可访问=否”。';

  @override
  String get obj_store_settings_cleared_title => '已清除';

  @override
  String get obj_store_settings_cleared_content => '已将资源存储恢复为未选择';

  @override
  String get obj_store_settings_invalid_title => '提示';

  @override
  String get obj_store_settings_qiniu_config_incomplete_error =>
      '七牛云配置不完整，请检查 Bucket / 访问域名 / 上传域名';

  @override
  String get obj_store_settings_qiniu_missing_credentials_error =>
      '请填写七牛云 AccessKey / SecretKey';

  @override
  String get obj_store_settings_data_capsule_config_incomplete_error =>
      '数据胶囊配置不完整，请检查 Bucket / Endpoint';

  @override
  String get obj_store_settings_data_capsule_missing_credentials_error =>
      '请填写数据胶囊 AccessKey（AK）/ SecretKey（SK）';

  @override
  String get obj_store_settings_saved_title => '已保存';

  @override
  String get obj_store_settings_saved_content => '资源存储配置已保存';

  @override
  String get obj_store_settings_save_failed_title => '保存失败';

  @override
  String get obj_store_settings_test_upload_select_file_hint =>
      '请先选择一个要测试上传的图片/视频文件';

  @override
  String get obj_store_settings_test_upload_read_failed_hint =>
      '无法读取文件内容，请重新选择';

  @override
  String get obj_store_settings_upload_success_title => '上传成功';

  @override
  String get obj_store_settings_upload_failed_title => '上传失败';

  @override
  String get obj_store_settings_test_query_key_required_hint => '请填写要查询的 Key';

  @override
  String get obj_store_settings_query_failed_title => '查询失败';

  @override
  String get obj_store_settings_clear_confirm_title => '确认清除';

  @override
  String get obj_store_settings_clear_confirm_content =>
      '将清除资源存储的所有配置（包含密钥等敏感信息）';

  @override
  String obj_store_settings_dialog_obj_content(Object key, Object uri) {
    return 'Key: $key\\nURI: $uri';
  }

  @override
  String get obj_store_settings_copy_redacted_action => '复制脱敏内容';

  @override
  String get obj_store_settings_copy_original_action => '复制原始内容';

  @override
  String get obj_store_settings_copy_original_confirm_title => '复制原始 URI？';

  @override
  String get obj_store_settings_copy_original_confirm_content =>
      '原始 URI 可能包含签名/令牌等敏感信息，复制后请勿截图或分享。';

  @override
  String get obj_store_settings_query_result_title => '查询结果';

  @override
  String obj_store_settings_dialog_query_content(
    Object uri,
    Object accessible,
  ) {
    return 'URI: $uri\\n可访问: $accessible';
  }

  @override
  String get obj_store_settings_copy_redacted_result_action => '复制脱敏结果';

  @override
  String get obj_store_settings_copy_original_result_action => '复制原始结果';
}

/// The translations for Chinese, as used in China (`zh_CN`).
class AppLocalizationsZhCn extends AppLocalizationsZh {
  AppLocalizationsZhCn() : super('zh_CN');

  @override
  String get appTitle => '小蜜';

  @override
  String get common_confirm => '确认';

  @override
  String get common_cancel => '取消';

  @override
  String get common_delete => '删除';

  @override
  String get common_save => '保存';

  @override
  String get common_loading => '加载中...';

  @override
  String get common_copy => '复制';

  @override
  String get common_yes => '是';

  @override
  String get common_no => '否';

  @override
  String get common_public => '公有';

  @override
  String get common_private => '私有';

  @override
  String get common_home => '首页';

  @override
  String get common_tasks => '任务';

  @override
  String get common_calendar => '日历';

  @override
  String get tool_management_title => '工具管理';

  @override
  String tool_management_hint_content(Object hiddenCount) {
    return '首页长按工具卡片并拖拽可调整顺序。\\n这里可设置启动默认进入工具，并选择是否在首页显示（已隐藏 $hiddenCount 个）。';
  }

  @override
  String get tool_management_default_tool_title => '启动默认进入';

  @override
  String get tool_management_default_tool_subtitle => '设置后，下次打开应用将直接进入该工具';

  @override
  String get tool_management_home_visibility_title => '首页显示';

  @override
  String get tool_management_home_visibility_subtitle =>
      '关闭后首页不显示该工具（不影响备份与默认进入）';

  @override
  String get tool_stockpile_name => '囤货助手';

  @override
  String get tool_overcooked_name => '胡闹厨房';

  @override
  String get tool_work_log_name => '工作记录';

  @override
  String get work_log_ai_entry => 'AI录入';

  @override
  String get sync_user_mismatch_title => '同步用户不匹配';

  @override
  String sync_user_mismatch_content(Object localUserId, Object serverUserId) {
    return '检测到本地数据属于“$localUserId”，但当前同步用户为“$serverUserId”。继续同步可能会覆盖其中一端的数据，请选择处理方式。';
  }

  @override
  String get sync_user_mismatch_overwrite_local => '覆盖本地（使用服务端）';

  @override
  String get sync_user_mismatch_overwrite_server => '覆盖服务端（使用本地）';

  @override
  String get common_refresh => '刷新';

  @override
  String get common_export => '导出';

  @override
  String get common_restore => '还原';

  @override
  String get common_clear => '清空';

  @override
  String get common_add => '添加';

  @override
  String get common_continue => '继续';

  @override
  String get common_load_more => '加载更多';

  @override
  String get common_not_configured => '未配置';

  @override
  String get common_go_settings => '去设置';

  @override
  String get network_status_wifi => 'WiFi';

  @override
  String get network_status_mobile => '移动网络';

  @override
  String get network_status_offline => '离线';

  @override
  String get network_status_unknown => '未知';

  @override
  String get backup_restore_title => '备份与还原';

  @override
  String get backup_received_title => '已接收备份文件';

  @override
  String get backup_received_content => '备份内容已填入，请检查后点击“开始还原”按钮。';

  @override
  String get backup_export_hint_intro => '将以下内容导出为 JSON（大数据量推荐导出为 TXT 文件）：';

  @override
  String get backup_export_hint_items =>
      '1) AI 配置（接口地址 / 模型 / 参数）\\n2) 数据同步配置（服务器/网络模式等）\\n3) 资源存储配置（七牛/本地）\\n4) 工具管理（默认进入/首页显示/工具排序等应用配置）\\n5) 各工具数据（通过 ToolSyncProvider 导出）';

  @override
  String get backup_include_sensitive_label => '包含敏感信息（AI 密钥 / 同步令牌 / 存储密钥）';

  @override
  String get backup_include_sensitive_on_hint =>
      '默认已开启：导出内容会包含密钥/令牌，分享前请确认接收方可信。';

  @override
  String get backup_include_sensitive_off_hint =>
      '已关闭：不导出密钥/令牌（更安全，导入后可在设置页重新填写）。';

  @override
  String get backup_export_share_button => '导出并分享';

  @override
  String get backup_export_save_txt_button => '保存为 TXT 文件';

  @override
  String get backup_export_copy_clipboard_button => '导出 JSON 到剪切板';

  @override
  String get backup_restore_hint => '粘贴 JSON 并覆盖写入本地（请谨慎操作，建议先导出备份）。';

  @override
  String get backup_restore_placeholder => '在此粘贴备份 JSON…';

  @override
  String get backup_restore_paste_button => '从剪切板粘贴';

  @override
  String get backup_restore_import_txt_button => '从 TXT 文件导入';

  @override
  String get backup_restore_start_button => '开始还原（覆盖本地）';

  @override
  String get backup_share_success_title => '分享成功';

  @override
  String get backup_share_success_content => '备份文件已分享';

  @override
  String get backup_share_failed_title => '分享失败';

  @override
  String get backup_exported_title => '已导出';

  @override
  String backup_exported_saved_content(Object path, Object kb) {
    return '已保存到：\\n$path\\n\\n内容为紧凑 JSON（约 $kb KB）';
  }

  @override
  String get backup_export_failed_title => '导出失败';

  @override
  String backup_exported_copied_content(Object kb) {
    return '紧凑 JSON 已复制到剪切板（约 $kb KB）';
  }

  @override
  String get backup_file_picker_title => '选择备份 TXT 文件';

  @override
  String get backup_import_failed_title => '导入失败';

  @override
  String backup_restore_summary_imported(Object count) {
    return '已导入工具：$count';
  }

  @override
  String backup_restore_summary_skipped(Object count) {
    return '已跳过工具：$count';
  }

  @override
  String backup_restore_summary_failed(Object tools) {
    return '失败工具：$tools';
  }

  @override
  String get backup_restore_complete_title => '还原完成';

  @override
  String get backup_restore_failed_title => '还原失败';

  @override
  String get backup_confirm_restore_title => '确认还原？';

  @override
  String get backup_confirm_restore_content => '该操作会覆盖本地配置与数据，建议先导出备份。';

  @override
  String get sync_settings_title => '数据同步';

  @override
  String get sync_network_type_section_title => '网络类型';

  @override
  String get sync_network_public_label => '公网模式';

  @override
  String get sync_network_private_label => '私网模式';

  @override
  String get sync_network_public_hint => '公网模式：只要有网络即可同步';

  @override
  String get sync_network_private_hint => '私网模式：仅允许在指定 WiFi 下同步（用于家庭/公司内网）';

  @override
  String get sync_basic_section_title => '基本配置';

  @override
  String get sync_user_id_label => '用户 ID';

  @override
  String get sync_user_id_placeholder => '用于服务端区分用户';

  @override
  String get sync_server_url_label => '服务器地址';

  @override
  String get sync_server_url_placeholder =>
      '例如 https://sync.example.com 或 http://127.0.0.1';

  @override
  String get sync_port_label => '端口';

  @override
  String get sync_port_placeholder => '默认 443';

  @override
  String get sync_server_url_tip =>
      '提示：本地部署（docker/uvicorn）通常是 http + 8080，请显式填写 http:// 避免 TLS 握手错误。';

  @override
  String get sync_allowed_wifi_section_title => '允许的 WiFi（SSID）';

  @override
  String sync_current_wifi_label(Object ssid) {
    return '当前 WiFi：$ssid';
  }

  @override
  String get sync_current_wifi_unknown_hint => '当前 WiFi：未知（可点右侧刷新）';

  @override
  String get sync_allowed_wifi_empty_hint => '未配置允许的 WiFi 名称';

  @override
  String get sync_wifi_ssid_tip => '提示：SSID 区分大小写，建议不要包含引号和首尾空格';

  @override
  String get sync_advanced_section_title => '高级选项';

  @override
  String get sync_auto_sync_on_startup_label => '启动时自动同步';

  @override
  String get sync_section_title => '同步';

  @override
  String get sync_now_button => '立即同步';

  @override
  String sync_last_sync_label(Object time) {
    return '上次同步：$time';
  }

  @override
  String get sync_last_sync_none => '上次同步：暂无';

  @override
  String get sync_success_label => '同步成功';

  @override
  String get sync_error_details_label => '错误详情：';

  @override
  String get sync_copy_error_details_button => '复制错误详情';

  @override
  String sync_current_network_hint(Object network) {
    return '当前网络：$network（私网模式需 WiFi）';
  }

  @override
  String get sync_wifi_permission_hint =>
      '无法获取 SSID：未获得定位权限（Android 读取 WiFi 名称需要定位权限）';

  @override
  String get sync_wifi_ssid_unavailable_hint =>
      '已连接 WiFi，但无法获取 SSID（可能缺少定位权限/未开启定位/系统限制）';

  @override
  String get sync_location_permission_required_title => '需要定位权限';

  @override
  String get sync_location_permission_required_content =>
      'Android 读取当前 WiFi 名称（SSID）需要定位权限，请在系统弹窗中选择允许后再重试。';

  @override
  String get sync_permission_permanently_denied_title => '权限被永久拒绝';

  @override
  String get sync_permission_permanently_denied_content =>
      '请前往系统设置开启定位权限后再获取 WiFi 名称。';

  @override
  String get sync_config_invalid_title => '提示';

  @override
  String get sync_config_invalid_content => '配置不完整，请检查必填项（私网模式需至少配置 1 个 WiFi）';

  @override
  String get sync_config_saved_title => '已保存';

  @override
  String get sync_config_saved_content => '同步配置已更新';

  @override
  String get sync_finished_title_success => '同步完成';

  @override
  String get sync_finished_title_failed => '同步失败';

  @override
  String get sync_finished_content_success => '已完成同步';

  @override
  String get sync_finished_content_failed => '请查看页面内的错误详情';

  @override
  String get sync_add_wifi_title => '添加 WiFi 名称（SSID）';

  @override
  String get sync_add_wifi_placeholder => '例如 MyHomeWifi';

  @override
  String get sync_records_title => '同步记录';

  @override
  String get sync_details_title => '同步详情';

  @override
  String get sync_records_config_missing_error => '同步配置未设置或不完整，请先完成配置后再查看同步记录。';

  @override
  String get sync_details_config_missing_error => '同步配置未设置或不完整，请先完成配置后再查看同步详情。';

  @override
  String get sync_server_label => '服务端';

  @override
  String sync_user_label(Object userId) {
    return '用户：$userId';
  }

  @override
  String get sync_open_settings_button => '同步设置';

  @override
  String get sync_go_config_button => '去配置数据同步';

  @override
  String get sync_records_empty_hint => '暂无同步记录（仅记录发生“客户端更新/服务端更新/回退”的同步行为）';

  @override
  String get sync_direction_client_to_server => '客户端 → 服务端';

  @override
  String get sync_direction_server_to_client => '服务端 → 客户端';

  @override
  String get sync_direction_rollback => '服务端回退';

  @override
  String get sync_direction_unknown => '未知操作';

  @override
  String sync_summary_changed_tools(Object count) {
    return '变更工具 $count';
  }

  @override
  String sync_summary_changed_items(Object count, Object plus) {
    return '变更项 $count$plus';
  }

  @override
  String get sync_summary_no_major_changes => '无主要变更';

  @override
  String get sync_action_client_updates_server => '客户端更新服务端';

  @override
  String get sync_action_server_updates_client => '服务端更新客户端';

  @override
  String get sync_action_rollback_server => '回退（服务端）';

  @override
  String get sync_action_unknown => '未知';

  @override
  String sync_details_time_label(Object time) {
    return '时间：$time';
  }

  @override
  String sync_details_client_updated_at_label(Object ms) {
    return '客户端更新时间：$ms';
  }

  @override
  String sync_details_server_updated_at_label(Object before, Object after) {
    return '服务端更新时间：$before → $after';
  }

  @override
  String sync_details_server_revision_label(Object before, Object after) {
    return '服务端游标：$before → $after';
  }

  @override
  String get sync_rollback_section_title => '版本恢复';

  @override
  String get sync_rollback_section_hint => '您可以将数据恢复到此同步记录之前的状态。';

  @override
  String get sync_rollback_to_version_title => '恢复到此版本';

  @override
  String get sync_rollback_to_version_subtitle => '云端和本地都将回退';

  @override
  String get sync_rollback_local_only_title => '仅恢复本地';

  @override
  String get sync_rollback_local_only_subtitle => '仅本地预览，不影响云端';

  @override
  String sync_rollback_target_revision(Object revision) {
    return '版本号 $revision';
  }

  @override
  String get sync_rollback_no_target => '无可恢复版本';

  @override
  String get sync_not_configured_title => '同步未配置';

  @override
  String get sync_not_configured_content => '请先完成服务器地址/端口与用户标识配置，然后再进行回退操作。';

  @override
  String get sync_network_precheck_failed_title => '网络预检失败';

  @override
  String get sync_confirm_rollback_server_title => '确认回退服务端？';

  @override
  String sync_confirm_rollback_server_content(Object revision) {
    return '将服务端回退到 $revision，并覆盖本地数据。该操作会产生新的服务端版本。';
  }

  @override
  String get sync_confirm_rollback_server_confirm => '回退';

  @override
  String get sync_rollback_done_title => '回退完成';

  @override
  String sync_rollback_done_content(Object revision, Object newRevision) {
    return '已回退到 $revision，并覆盖本地。新的服务端版本：$newRevision';
  }

  @override
  String sync_rollback_done_partial_content(Object error) {
    return '服务端已回退，但部分工具导入失败：\\n$error';
  }

  @override
  String get sync_rollback_failed_title => '回退失败';

  @override
  String get sync_confirm_rollback_local_title => '确认仅回退本地？';

  @override
  String sync_confirm_rollback_local_content(Object revision) {
    return '将本地数据覆盖为服务端历史版本 $revision，但不会修改服务端当前版本。\\n注意：下次同步时本地可能被服务端覆盖（建议改用“回退服务端并覆盖本地”）。';
  }

  @override
  String get sync_confirm_rollback_local_confirm => '覆盖本地';

  @override
  String get sync_overwrite_local_done_title => '已覆盖本地';

  @override
  String sync_overwrite_local_done_content(Object revision) {
    return '本地已覆盖为 $revision';
  }

  @override
  String sync_overwrite_local_done_partial_content(Object error) {
    return '部分工具导入失败：\\n$error';
  }

  @override
  String get sync_overwrite_local_failed_title => '覆盖失败';

  @override
  String get sync_diff_none => '无差异详情';

  @override
  String get sync_diff_format_error => '差异数据格式错误';

  @override
  String get sync_diff_no_substantive => '无实质性数据变更（仅包含被忽略的长度变化）';

  @override
  String get sync_diff_unknown_item => '• 未知差异项';

  @override
  String get tool_tag_manager_name => '标签管理';

  @override
  String get tool_app_config_name => '应用配置';

  @override
  String get tag_category_location => '位置';

  @override
  String get tag_category_item_type => '物品类型';

  @override
  String get tag_category_dish_type => '菜品类型';

  @override
  String get tag_category_ingredient => '食材';

  @override
  String get tag_category_sauce => '酱料';

  @override
  String get tag_category_affiliation => '归属';

  @override
  String get tag_category_flavor => '风味';

  @override
  String get tag_category_meal_slot => '餐次';

  @override
  String get sync_diff_label_added => '新增';

  @override
  String get sync_diff_label_removed => '删除';

  @override
  String get sync_diff_label_modified => '修改';

  @override
  String get sync_diff_label_type_changed => '类型变更';

  @override
  String get sync_diff_content_changed => '内容已变更';

  @override
  String get sync_diff_added_data => '新增了数据';

  @override
  String get sync_diff_removed_data => '删除了数据';

  @override
  String sync_diff_detail_tag_added(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return '新增了$toolName下$categoryName类型的标签：【$tagName】';
  }

  @override
  String sync_diff_detail_tag_removed(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return '删除了$toolName下$categoryName类型的标签：【$tagName】';
  }

  @override
  String sync_diff_detail_named_added(Object name) {
    return '新增了：【$name】';
  }

  @override
  String sync_diff_detail_named_removed(Object name) {
    return '删除了：【$name】';
  }

  @override
  String sync_diff_detail_titled_added(Object title) {
    return '新增了：【$title】';
  }

  @override
  String sync_diff_detail_titled_removed(Object title) {
    return '删除了：【$title】';
  }

  @override
  String sync_diff_path_item(Object index) {
    return '第$index项';
  }

  @override
  String get sync_auto_sync_success_toast => '自动同步成功';

  @override
  String sync_auto_sync_failed_toast(Object error) {
    return '自动同步失败: $error';
  }

  @override
  String get ai_settings_title => 'AI配置';

  @override
  String get ai_settings_openai_section_title => 'OpenAI 兼容配置';

  @override
  String get ai_settings_base_url_label => '接口地址（Base URL）';

  @override
  String get ai_settings_base_url_placeholder => 'https://api.openai.com/v1';

  @override
  String get ai_settings_api_key_label => 'API 密钥（Key）';

  @override
  String get ai_settings_api_key_placeholder => 'sk-...';

  @override
  String get ai_settings_model_label => '模型（Model）';

  @override
  String get ai_settings_model_placeholder => 'gpt-4o-mini';

  @override
  String get ai_settings_temperature_label => '温度（Temperature）';

  @override
  String get ai_settings_temperature_placeholder => '0.7';

  @override
  String get ai_settings_max_tokens_label => '最大输出（Max Tokens）';

  @override
  String get ai_settings_max_tokens_placeholder => '1024';

  @override
  String get ai_settings_test_button => '测试连接';

  @override
  String get ai_settings_testing_button => '测试中...';

  @override
  String get ai_settings_tips_section_title => '说明';

  @override
  String get ai_settings_tips_content =>
      '1. 接口地址支持填写到域名（如 https://example.com），也可直接填写到 /v1。\\n2. 当前使用 OpenAI 兼容接口：/v1/chat/completions。\\n3. API 密钥将保存在本机（SharedPreferences）。';

  @override
  String get ai_settings_danger_section_title => '危险区';

  @override
  String get ai_settings_clear_button => '清除AI配置';

  @override
  String get ai_settings_invalid_title => '提示';

  @override
  String get ai_settings_invalid_content =>
      '请检查配置项：接口地址 / API 密钥 / 模型不能为空；温度范围 0~2；最大输出 > 0。';

  @override
  String get ai_settings_saved_title => '已保存';

  @override
  String ai_settings_saved_content(Object model) {
    return '当前模型：$model';
  }

  @override
  String get ai_settings_test_invalid_content => '请先填写合法的 AI 配置，再进行测试。';

  @override
  String get ai_settings_testing_loading_title => '测试中';

  @override
  String get ai_settings_test_result_title => '测试结果';

  @override
  String get ai_settings_test_failed_title => '测试失败';

  @override
  String get ai_settings_clear_confirm_title => '确认清除？';

  @override
  String get ai_settings_clear_confirm_content => '清除后将无法使用 AI 相关功能，直到重新配置。';

  @override
  String get ai_settings_clear_confirm_button => '清除';

  @override
  String get obj_store_settings_title => '资源存储';

  @override
  String get obj_store_settings_type_section_title => '存储方式';

  @override
  String get obj_store_settings_type_none_label => '未选择';

  @override
  String get obj_store_settings_type_local_label => '本地存储';

  @override
  String get obj_store_settings_type_qiniu_label => '七牛云';

  @override
  String get obj_store_settings_type_data_capsule_label => '数据胶囊';

  @override
  String get obj_store_settings_qiniu_section_title => '七牛云配置';

  @override
  String get obj_store_settings_data_capsule_section_title => '数据胶囊配置';

  @override
  String get obj_store_settings_test_section_title => '测试';

  @override
  String get obj_store_settings_tips_section_title => '说明';

  @override
  String get obj_store_settings_danger_section_title => '危险区';

  @override
  String get obj_store_settings_clear_button => '清除资源存储配置';

  @override
  String get obj_store_settings_bucket_type_label => '空间类型';

  @override
  String get obj_store_settings_protocol_label => '访问协议';

  @override
  String get obj_store_settings_protocol_https_label => 'https';

  @override
  String get obj_store_settings_protocol_http_label => 'http';

  @override
  String get obj_store_settings_http_security_warning =>
      '安全提示：HTTP 为明文传输，访问密钥/文件内容可能被截获，仅建议内网调试使用。';

  @override
  String get obj_store_settings_access_key_label => 'AccessKey（访问密钥）';

  @override
  String get obj_store_settings_secret_key_label => 'SecretKey（私密密钥）';

  @override
  String get obj_store_settings_access_key_ak_label => 'AccessKey（AK）';

  @override
  String get obj_store_settings_secret_key_sk_label => 'SecretKey（SK）';

  @override
  String get obj_store_settings_bucket_label => 'Bucket';

  @override
  String get obj_store_settings_domain_label => '访问域名（用于拼接图片URL）';

  @override
  String get obj_store_settings_upload_host_label => '上传域名（可选）';

  @override
  String get obj_store_settings_key_prefix_label => 'Key 前缀（可选）';

  @override
  String get obj_store_settings_endpoint_label => 'Endpoint（上传/访问）';

  @override
  String get obj_store_settings_domain_optional_label => '访问域名（可选）';

  @override
  String get obj_store_settings_region_label => 'Region';

  @override
  String get obj_store_settings_url_style_label => 'URL 风格';

  @override
  String get obj_store_settings_fixed_private_value => '私有（固定）';

  @override
  String get obj_store_settings_fixed_https_value => 'https（固定）';

  @override
  String get obj_store_settings_fixed_path_style_value => '路径风格（固定）';

  @override
  String obj_store_settings_fixed_region_value(Object region) {
    return '$region（固定）';
  }

  @override
  String get obj_store_settings_placeholder_example_short => '如：xxxxx';

  @override
  String get obj_store_settings_placeholder_bucket => '如：my-bucket';

  @override
  String get obj_store_settings_placeholder_domain => '如：cdn.example.com';

  @override
  String get obj_store_settings_placeholder_upload_host =>
      '默认：https://upload.qiniup.com';

  @override
  String get obj_store_settings_placeholder_endpoint => '如：s3.example.com';

  @override
  String get obj_store_settings_placeholder_key_prefix => '如：media/';

  @override
  String get obj_store_settings_placeholder_query => '如：media/xxx.png';

  @override
  String get obj_store_settings_test_file_not_selected => '未选择文件';

  @override
  String obj_store_settings_test_file_selected(Object name, Object bytes) {
    return '$name（$bytes bytes）';
  }

  @override
  String get obj_store_settings_choose_file_button => '选择文件';

  @override
  String get obj_store_settings_test_upload_button => '测试上传';

  @override
  String get obj_store_settings_test_uploading_button => '测试上传中...';

  @override
  String get obj_store_settings_test_query_button => '测试查询';

  @override
  String get obj_store_settings_test_querying_button => '查询中...';

  @override
  String obj_store_settings_test_upload_result(Object key, Object uri) {
    return '上传结果：\\nKey: $key\\nURI: $uri';
  }

  @override
  String get obj_store_settings_query_key_label =>
      '查询 Key / URL（用于测试查询/拼接URL，支持粘贴完整 URL）';

  @override
  String get obj_store_settings_tips_content =>
      '1. 本地存储会将文件写入应用私有目录（卸载应用后会被清理）。\\n2. 七牛云存储会在本机生成上传凭证并直接上传到七牛。\\n3. 七牛私有空间查询会生成带签名的临时下载链接。\\n4. 数据胶囊为私有空间，查询会生成带签名的临时链接（默认 30 分钟）。\\n5. 访问密钥属于敏感信息，仅建议自用场景配置；如需更安全的方案，建议使用服务端下发的上传凭证。\\n6. 如配置了自定义访问域名，请确保与服务端配置一致，避免出现“可访问=否”。';

  @override
  String get obj_store_settings_cleared_title => '已清除';

  @override
  String get obj_store_settings_cleared_content => '已将资源存储恢复为未选择';

  @override
  String get obj_store_settings_invalid_title => '提示';

  @override
  String get obj_store_settings_qiniu_config_incomplete_error =>
      '七牛云配置不完整，请检查 Bucket / 访问域名 / 上传域名';

  @override
  String get obj_store_settings_qiniu_missing_credentials_error =>
      '请填写七牛云 AccessKey / SecretKey';

  @override
  String get obj_store_settings_data_capsule_config_incomplete_error =>
      '数据胶囊配置不完整，请检查 Bucket / Endpoint';

  @override
  String get obj_store_settings_data_capsule_missing_credentials_error =>
      '请填写数据胶囊 AccessKey（AK）/ SecretKey（SK）';

  @override
  String get obj_store_settings_saved_title => '已保存';

  @override
  String get obj_store_settings_saved_content => '资源存储配置已保存';

  @override
  String get obj_store_settings_save_failed_title => '保存失败';

  @override
  String get obj_store_settings_test_upload_select_file_hint =>
      '请先选择一个要测试上传的图片/视频文件';

  @override
  String get obj_store_settings_test_upload_read_failed_hint =>
      '无法读取文件内容，请重新选择';

  @override
  String get obj_store_settings_upload_success_title => '上传成功';

  @override
  String get obj_store_settings_upload_failed_title => '上传失败';

  @override
  String get obj_store_settings_test_query_key_required_hint => '请填写要查询的 Key';

  @override
  String get obj_store_settings_query_failed_title => '查询失败';

  @override
  String get obj_store_settings_clear_confirm_title => '确认清除';

  @override
  String get obj_store_settings_clear_confirm_content =>
      '将清除资源存储的所有配置（包含密钥等敏感信息）';

  @override
  String obj_store_settings_dialog_obj_content(Object key, Object uri) {
    return 'Key: $key\\nURI: $uri';
  }

  @override
  String get obj_store_settings_copy_redacted_action => '复制脱敏内容';

  @override
  String get obj_store_settings_copy_original_action => '复制原始内容';

  @override
  String get obj_store_settings_copy_original_confirm_title => '复制原始 URI？';

  @override
  String get obj_store_settings_copy_original_confirm_content =>
      '原始 URI 可能包含签名/令牌等敏感信息，复制后请勿截图或分享。';

  @override
  String get obj_store_settings_query_result_title => '查询结果';

  @override
  String obj_store_settings_dialog_query_content(
    Object uri,
    Object accessible,
  ) {
    return 'URI: $uri\\n可访问: $accessible';
  }

  @override
  String get obj_store_settings_copy_redacted_result_action => '复制脱敏结果';

  @override
  String get obj_store_settings_copy_original_result_action => '复制原始结果';
}
