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
  String get tool_management_title => '工具管理';

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
  String get tool_management_title => '工具管理';

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
}
