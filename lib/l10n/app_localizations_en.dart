// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Honey';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_save => 'Save';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_home => 'Home';

  @override
  String get common_tasks => 'Tasks';

  @override
  String get common_calendar => 'Calendar';

  @override
  String get tool_management_title => 'Tool Management';

  @override
  String get tool_stockpile_name => 'Stockpile Assistant';

  @override
  String get tool_overcooked_name => 'Overcooked Kitchen';

  @override
  String get tool_work_log_name => 'Work Log';

  @override
  String get work_log_ai_entry => 'AI Entry';

  @override
  String get sync_user_mismatch_title => 'Sync user mismatch';

  @override
  String sync_user_mismatch_content(Object localUserId, Object serverUserId) {
    return 'Local data belongs to “$localUserId”, but current sync user is “$serverUserId”. To avoid overwriting data, choose how to proceed.';
  }

  @override
  String get sync_user_mismatch_overwrite_local =>
      'Overwrite local (use server)';

  @override
  String get sync_user_mismatch_overwrite_server =>
      'Overwrite server (use local)';
}

/// The translations for English, as used in the United States (`en_US`).
class AppLocalizationsEnUs extends AppLocalizationsEn {
  AppLocalizationsEnUs() : super('en_US');

  @override
  String get appTitle => 'Honey';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_save => 'Save';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_home => 'Home';

  @override
  String get common_tasks => 'Tasks';

  @override
  String get common_calendar => 'Calendar';

  @override
  String get tool_management_title => 'Tool Management';

  @override
  String get tool_stockpile_name => 'Stockpile Assistant';

  @override
  String get tool_overcooked_name => 'Overcooked Kitchen';

  @override
  String get tool_work_log_name => 'Work Log';

  @override
  String get work_log_ai_entry => 'AI Entry';

  @override
  String get sync_user_mismatch_title => 'Sync user mismatch';

  @override
  String sync_user_mismatch_content(Object localUserId, Object serverUserId) {
    return 'Local data belongs to “$localUserId”, but current sync user is “$serverUserId”. To avoid overwriting data, choose how to proceed.';
  }

  @override
  String get sync_user_mismatch_overwrite_local =>
      'Overwrite local (use server)';

  @override
  String get sync_user_mismatch_overwrite_server =>
      'Overwrite server (use local)';
}
