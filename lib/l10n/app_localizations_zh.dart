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
  String get tool_management_title => '工具管理';

  @override
  String get tool_stockpile_name => '囤货助手';

  @override
  String get tool_overcooked_name => '胡闹厨房';

  @override
  String get tool_work_log_name => '工作记录';
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
  String get tool_management_title => '工具管理';

  @override
  String get tool_stockpile_name => '囤货助手';

  @override
  String get tool_overcooked_name => '胡闹厨房';

  @override
  String get tool_work_log_name => '工作记录';
}
