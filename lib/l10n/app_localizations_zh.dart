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
  String get common_home => '首页';

  @override
  String get common_tasks => '任务';

  @override
  String get common_calendar => '日历';

  @override
  String get settings_dark_mode_label => '深色模式';

  @override
  String get tool_management_title => '工具管理';

  @override
  String get tool_stockpile_name => '囤货助手';

  @override
  String get tool_overcooked_name => '胡闹厨房';

  @override
  String get overcooked_recipe_edit_ai_generate => 'AI 生成';

  @override
  String get overcooked_recipe_edit_ai_generating_overlay => '菜谱生成中…';

  @override
  String get overcooked_recipe_edit_markdown_hint => '支持 Markdown，建议生成后再按需微调';

  @override
  String get overcooked_recipe_edit_ai_need_name_content => '请先填写菜名，再使用 AI 生成。';

  @override
  String get overcooked_recipe_edit_ai_service_missing_content =>
      '未找到 AI 服务，请确认已在应用入口注入 AiService。';

  @override
  String get overcooked_recipe_edit_ai_empty_content => 'AI 返回内容为空，请稍后重试。';

  @override
  String get overcooked_recipe_edit_ai_not_configured_content =>
      '请先在“设置 -> AI 设置”完成配置后再生成菜谱。';

  @override
  String get overcooked_recipe_detail_immersive_read => '沉浸式阅读';

  @override
  String get overcooked_recipe_markdown_page_title => '沉浸式阅读';

  @override
  String get tool_work_log_name => '工作记录';

  @override
  String get work_log_ai_entry => 'AI录入';

  @override
  String get work_log_ai_summary_entry => 'AI总结';

  @override
  String get work_log_ai_summary_title => 'AI总结';

  @override
  String get work_log_ai_summary_range_title => '时间范围';

  @override
  String get work_log_ai_summary_start_date_label => '开始日期';

  @override
  String get work_log_ai_summary_end_date_label => '结束日期';

  @override
  String get work_log_ai_summary_range_hint => '统计范围包含开始与结束当天';

  @override
  String get work_log_ai_summary_task_title => '总结任务';

  @override
  String get work_log_ai_summary_task_empty => '暂无任务';

  @override
  String get work_log_ai_summary_task_no_hours => '无工时';

  @override
  String get work_log_ai_summary_affiliation_title => '归属筛选';

  @override
  String get work_log_ai_summary_affiliation_empty => '暂无可用归属';

  @override
  String get work_log_ai_summary_all_affiliations => '全部归属';

  @override
  String get work_log_ai_summary_style_title => '总结风格';

  @override
  String get work_log_ai_summary_style_concise => '精简周报';

  @override
  String get work_log_ai_summary_style_review => '复盘分析';

  @override
  String get work_log_ai_summary_style_risk => '风险导向';

  @override
  String get work_log_ai_summary_style_highlight => '成果亮点';

  @override
  String get work_log_ai_summary_style_management => '管理汇报';

  @override
  String work_log_ai_summary_data_hint(Object entryCount, Object minutes) {
    return '已选 $entryCount 条记录，共 $minutes 分钟';
  }

  @override
  String get work_log_ai_summary_generate_button => '生成总结';

  @override
  String get work_log_ai_summary_generating_hint => '正在生成总结，请耐心等待…';

  @override
  String work_log_ai_summary_generating_elapsed(Object seconds) {
    return '已等待 $seconds 秒';
  }

  @override
  String get work_log_ai_summary_result_title => '总结结果';

  @override
  String get work_log_ai_summary_copy_button => '复制';

  @override
  String get work_log_ai_summary_share_button => '分享';

  @override
  String get work_log_ai_summary_copy_done_title => '已复制';

  @override
  String get work_log_ai_summary_copy_done_content => '总结已复制到剪切板';

  @override
  String get work_log_ai_summary_share_done_title => '已分享';

  @override
  String get work_log_ai_summary_share_done_content => '总结文件已分享';

  @override
  String get work_log_ai_summary_share_failed_title => '分享失败';

  @override
  String get work_log_ai_summary_share_failed_content => '请稍后重试';

  @override
  String get work_log_ai_summary_no_data_title => '暂无可总结数据';

  @override
  String get work_log_ai_summary_no_data_content => '当前筛选下没有工时记录，请调整时间范围或筛选条件';

  @override
  String get work_log_ai_summary_ai_missing_title => 'AI 未配置';

  @override
  String get work_log_ai_summary_ai_missing_content =>
      '未找到 AI 服务，请先在设置中完成 AI 配置';

  @override
  String get work_log_ai_summary_generate_failed_title => '生成失败';

  @override
  String get work_log_ai_summary_generate_failed_content => 'AI 总结生成失败，请稍后重试';

  @override
  String get work_log_operation_logs_title => '操作日志';

  @override
  String get work_log_operation_logs_empty => '暂无操作记录';

  @override
  String work_log_operation_logs_limit_hint(int count) {
    return '仅可查看最近$count次操作';
  }

  @override
  String get work_log_operation_logs_today => '今天';

  @override
  String get work_log_operation_logs_yesterday => '昨天';

  @override
  String get work_log_operation_logs_limit_setting => '保留条数';

  @override
  String get work_log_operation_logs_limit_sheet_title => '设置保留条数';

  @override
  String get work_log_operation_logs_limit_sheet_message =>
      '调整后将仅保留最近指定条数的操作日志';

  @override
  String work_log_operation_logs_limit_option(int count) {
    return '$count 条';
  }

  @override
  String get work_log_calendar_month_mode => '月';

  @override
  String get work_log_calendar_week_mode => '周';

  @override
  String get work_log_calendar_day_mode => '日';

  @override
  String work_log_calendar_month_title(Object month) {
    return '$month月';
  }

  @override
  String work_log_calendar_month_subtitle(Object days) {
    return '本月有 $days 天记录工时';
  }

  @override
  String get work_log_calendar_week_subtitle => '周视图';

  @override
  String get work_log_calendar_day_subtitle => '日视图';

  @override
  String get work_log_calendar_selected_day_title => '当天记录';

  @override
  String work_log_calendar_selected_day_label(
    Object month,
    Object day,
    Object weekday,
  ) {
    return '$month月$day日 · $weekday';
  }

  @override
  String get work_log_calendar_recent_days_title => '近期记录';

  @override
  String get work_log_calendar_recent_days_empty => '本月暂无其他工时记录';

  @override
  String get work_log_calendar_no_entries_today => '当天暂无工时记录';

  @override
  String get work_log_calendar_total_label => '总计';

  @override
  String get work_log_calendar_content_label => '工作内容';

  @override
  String get work_log_calendar_task_label => '任务';

  @override
  String get work_log_calendar_no_content => '（无内容）';

  @override
  String get work_log_calendar_weekday_mon => '一';

  @override
  String get work_log_calendar_weekday_tue => '二';

  @override
  String get work_log_calendar_weekday_wed => '三';

  @override
  String get work_log_calendar_weekday_thu => '四';

  @override
  String get work_log_calendar_weekday_fri => '五';

  @override
  String get work_log_calendar_weekday_sat => '六';

  @override
  String get work_log_calendar_weekday_sun => '日';

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
  String get common_all => '全部';

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
  String get common_home => '首页';

  @override
  String get common_tasks => '任务';

  @override
  String get common_calendar => '日历';

  @override
  String get settings_dark_mode_label => '深色模式';

  @override
  String get tool_management_title => '工具管理';

  @override
  String get tool_stockpile_name => '囤货助手';

  @override
  String get tool_overcooked_name => '胡闹厨房';

  @override
  String get overcooked_recipe_edit_ai_generate => 'AI 生成';

  @override
  String get overcooked_recipe_edit_ai_generating_overlay => '菜谱生成中…';

  @override
  String get overcooked_recipe_edit_markdown_hint => '支持 Markdown，建议生成后再按需微调';

  @override
  String get overcooked_recipe_edit_ai_need_name_content => '请先填写菜名，再使用 AI 生成。';

  @override
  String get overcooked_recipe_edit_ai_service_missing_content =>
      '未找到 AI 服务，请确认已在应用入口注入 AiService。';

  @override
  String get overcooked_recipe_edit_ai_empty_content => 'AI 返回内容为空，请稍后重试。';

  @override
  String get overcooked_recipe_edit_ai_not_configured_content =>
      '请先在“设置 -> AI 设置”完成配置后再生成菜谱。';

  @override
  String get overcooked_recipe_detail_immersive_read => '沉浸式阅读';

  @override
  String get overcooked_recipe_markdown_page_title => '沉浸式阅读';

  @override
  String get tool_work_log_name => '工作记录';

  @override
  String get work_log_ai_entry => 'AI录入';

  @override
  String get work_log_ai_summary_entry => 'AI总结';

  @override
  String get work_log_ai_summary_title => 'AI总结';

  @override
  String get work_log_ai_summary_range_title => '时间范围';

  @override
  String get work_log_ai_summary_start_date_label => '开始日期';

  @override
  String get work_log_ai_summary_end_date_label => '结束日期';

  @override
  String get work_log_ai_summary_range_hint => '统计范围包含开始与结束当天';

  @override
  String get work_log_ai_summary_task_title => '总结任务';

  @override
  String get work_log_ai_summary_task_empty => '暂无任务';

  @override
  String get work_log_ai_summary_task_no_hours => '无工时';

  @override
  String get work_log_ai_summary_affiliation_title => '归属筛选';

  @override
  String get work_log_ai_summary_affiliation_empty => '暂无可用归属';

  @override
  String get work_log_ai_summary_all_affiliations => '全部归属';

  @override
  String get work_log_ai_summary_style_title => '总结风格';

  @override
  String get work_log_ai_summary_style_concise => '精简周报';

  @override
  String get work_log_ai_summary_style_review => '复盘分析';

  @override
  String get work_log_ai_summary_style_risk => '风险导向';

  @override
  String get work_log_ai_summary_style_highlight => '成果亮点';

  @override
  String get work_log_ai_summary_style_management => '管理汇报';

  @override
  String work_log_ai_summary_data_hint(Object entryCount, Object minutes) {
    return '已选 $entryCount 条记录，共 $minutes 分钟';
  }

  @override
  String get work_log_ai_summary_generate_button => '生成总结';

  @override
  String get work_log_ai_summary_generating_hint => '正在生成总结，请耐心等待…';

  @override
  String work_log_ai_summary_generating_elapsed(Object seconds) {
    return '已等待 $seconds 秒';
  }

  @override
  String get work_log_ai_summary_result_title => '总结结果';

  @override
  String get work_log_ai_summary_copy_button => '复制';

  @override
  String get work_log_ai_summary_share_button => '分享';

  @override
  String get work_log_ai_summary_copy_done_title => '已复制';

  @override
  String get work_log_ai_summary_copy_done_content => '总结已复制到剪切板';

  @override
  String get work_log_ai_summary_share_done_title => '已分享';

  @override
  String get work_log_ai_summary_share_done_content => '总结文件已分享';

  @override
  String get work_log_ai_summary_share_failed_title => '分享失败';

  @override
  String get work_log_ai_summary_share_failed_content => '请稍后重试';

  @override
  String get work_log_ai_summary_no_data_title => '暂无可总结数据';

  @override
  String get work_log_ai_summary_no_data_content => '当前筛选下没有工时记录，请调整时间范围或筛选条件';

  @override
  String get work_log_ai_summary_ai_missing_title => 'AI 未配置';

  @override
  String get work_log_ai_summary_ai_missing_content =>
      '未找到 AI 服务，请先在设置中完成 AI 配置';

  @override
  String get work_log_ai_summary_generate_failed_title => '生成失败';

  @override
  String get work_log_ai_summary_generate_failed_content => 'AI 总结生成失败，请稍后重试';

  @override
  String get work_log_operation_logs_title => '操作日志';

  @override
  String get work_log_operation_logs_empty => '暂无操作记录';

  @override
  String work_log_operation_logs_limit_hint(int count) {
    return '仅可查看最近$count次操作';
  }

  @override
  String get work_log_operation_logs_today => '今天';

  @override
  String get work_log_operation_logs_yesterday => '昨天';

  @override
  String get work_log_operation_logs_limit_setting => '保留条数';

  @override
  String get work_log_operation_logs_limit_sheet_title => '设置保留条数';

  @override
  String get work_log_operation_logs_limit_sheet_message =>
      '调整后将仅保留最近指定条数的操作日志';

  @override
  String work_log_operation_logs_limit_option(int count) {
    return '$count 条';
  }

  @override
  String get work_log_calendar_month_mode => '月';

  @override
  String get work_log_calendar_week_mode => '周';

  @override
  String get work_log_calendar_day_mode => '日';

  @override
  String work_log_calendar_month_title(Object month) {
    return '$month月';
  }

  @override
  String work_log_calendar_month_subtitle(Object days) {
    return '本月有 $days 天记录工时';
  }

  @override
  String get work_log_calendar_week_subtitle => '周视图';

  @override
  String get work_log_calendar_day_subtitle => '日视图';

  @override
  String get work_log_calendar_selected_day_title => '当天记录';

  @override
  String work_log_calendar_selected_day_label(
    Object month,
    Object day,
    Object weekday,
  ) {
    return '$month月$day日 · $weekday';
  }

  @override
  String get work_log_calendar_recent_days_title => '近期记录';

  @override
  String get work_log_calendar_recent_days_empty => '本月暂无其他工时记录';

  @override
  String get work_log_calendar_no_entries_today => '当天暂无工时记录';

  @override
  String get work_log_calendar_total_label => '总计';

  @override
  String get work_log_calendar_content_label => '工作内容';

  @override
  String get work_log_calendar_task_label => '任务';

  @override
  String get work_log_calendar_no_content => '（无内容）';

  @override
  String get work_log_calendar_weekday_mon => '一';

  @override
  String get work_log_calendar_weekday_tue => '二';

  @override
  String get work_log_calendar_weekday_wed => '三';

  @override
  String get work_log_calendar_weekday_thu => '四';

  @override
  String get work_log_calendar_weekday_fri => '五';

  @override
  String get work_log_calendar_weekday_sat => '六';

  @override
  String get work_log_calendar_weekday_sun => '日';

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
  String get common_all => '全部';

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
}
