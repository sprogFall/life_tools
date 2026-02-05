import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'US'),
    Locale('zh'),
    Locale('zh', 'CN'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Honey'**
  String get appTitle;

  /// No description provided for @common_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get common_loading;

  /// No description provided for @common_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get common_home;

  /// No description provided for @common_tasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get common_tasks;

  /// No description provided for @common_calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get common_calendar;

  /// No description provided for @tool_management_title.
  ///
  /// In en, this message translates to:
  /// **'Tool Management'**
  String get tool_management_title;

  /// No description provided for @tool_stockpile_name.
  ///
  /// In en, this message translates to:
  /// **'Stockpile Assistant'**
  String get tool_stockpile_name;

  /// No description provided for @tool_overcooked_name.
  ///
  /// In en, this message translates to:
  /// **'Overcooked Kitchen'**
  String get tool_overcooked_name;

  /// No description provided for @tool_work_log_name.
  ///
  /// In en, this message translates to:
  /// **'Work Log'**
  String get tool_work_log_name;

  /// No description provided for @work_log_ai_entry.
  ///
  /// In en, this message translates to:
  /// **'AI Entry'**
  String get work_log_ai_entry;

  /// Title shown when local data user does not match current sync user
  ///
  /// In en, this message translates to:
  /// **'Sync user mismatch'**
  String get sync_user_mismatch_title;

  /// Message shown when local data user does not match current sync user
  ///
  /// In en, this message translates to:
  /// **'Local data belongs to “{localUserId}”, but current sync user is “{serverUserId}”. To avoid overwriting data, choose how to proceed.'**
  String sync_user_mismatch_content(Object localUserId, Object serverUserId);

  /// Option to overwrite local data using server snapshot
  ///
  /// In en, this message translates to:
  /// **'Overwrite local (use server)'**
  String get sync_user_mismatch_overwrite_local;

  /// Option to overwrite server data using local snapshot
  ///
  /// In en, this message translates to:
  /// **'Overwrite server (use local)'**
  String get sync_user_mismatch_overwrite_server;

  /// No description provided for @common_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get common_refresh;

  /// No description provided for @common_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get common_export;

  /// No description provided for @common_restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get common_restore;

  /// No description provided for @common_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get common_clear;

  /// No description provided for @common_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get common_add;

  /// No description provided for @common_continue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get common_continue;

  /// No description provided for @common_load_more.
  ///
  /// In en, this message translates to:
  /// **'Load More'**
  String get common_load_more;

  /// No description provided for @common_not_configured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get common_not_configured;

  /// No description provided for @common_go_settings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get common_go_settings;

  /// No description provided for @network_status_wifi.
  ///
  /// In en, this message translates to:
  /// **'Wi‑Fi'**
  String get network_status_wifi;

  /// No description provided for @network_status_mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get network_status_mobile;

  /// No description provided for @network_status_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get network_status_offline;

  /// No description provided for @network_status_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get network_status_unknown;

  /// No description provided for @backup_restore_title.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backup_restore_title;

  /// No description provided for @backup_received_title.
  ///
  /// In en, this message translates to:
  /// **'Backup received'**
  String get backup_received_title;

  /// No description provided for @backup_received_content.
  ///
  /// In en, this message translates to:
  /// **'Backup content has been filled in. Review it and tap \"Start Restore\".'**
  String get backup_received_content;

  /// No description provided for @backup_export_hint_intro.
  ///
  /// In en, this message translates to:
  /// **'Export the following as JSON (for large data, export as a TXT file):'**
  String get backup_export_hint_intro;

  /// No description provided for @backup_export_hint_items.
  ///
  /// In en, this message translates to:
  /// **'1) AI settings (Base URL / model / params)\\n2) Sync settings (server / network mode, etc.)\\n3) Object store settings (Qiniu / local)\\n4) Tool management (default tool / home visibility / tool order, etc.)\\n5) Tool data (exported via ToolSyncProvider)'**
  String get backup_export_hint_items;

  /// No description provided for @backup_include_sensitive_label.
  ///
  /// In en, this message translates to:
  /// **'Include sensitive info (AI key / sync token / storage keys)'**
  String get backup_include_sensitive_label;

  /// No description provided for @backup_include_sensitive_on_hint.
  ///
  /// In en, this message translates to:
  /// **'Enabled by default: the export will include keys/tokens. Only share with trusted recipients.'**
  String get backup_include_sensitive_on_hint;

  /// No description provided for @backup_include_sensitive_off_hint.
  ///
  /// In en, this message translates to:
  /// **'Disabled: keys/tokens won’t be exported (safer; you can re-enter them in Settings after restore).'**
  String get backup_include_sensitive_off_hint;

  /// No description provided for @backup_export_share_button.
  ///
  /// In en, this message translates to:
  /// **'Export & Share'**
  String get backup_export_share_button;

  /// No description provided for @backup_export_save_txt_button.
  ///
  /// In en, this message translates to:
  /// **'Save as TXT'**
  String get backup_export_save_txt_button;

  /// No description provided for @backup_export_copy_clipboard_button.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON to Clipboard'**
  String get backup_export_copy_clipboard_button;

  /// No description provided for @backup_restore_hint.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON and overwrite local settings & data (be careful; export a backup first).'**
  String get backup_restore_hint;

  /// No description provided for @backup_restore_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Paste backup JSON here…'**
  String get backup_restore_placeholder;

  /// No description provided for @backup_restore_paste_button.
  ///
  /// In en, this message translates to:
  /// **'Paste from Clipboard'**
  String get backup_restore_paste_button;

  /// No description provided for @backup_restore_import_txt_button.
  ///
  /// In en, this message translates to:
  /// **'Import from TXT'**
  String get backup_restore_import_txt_button;

  /// No description provided for @backup_restore_start_button.
  ///
  /// In en, this message translates to:
  /// **'Start Restore (Overwrite Local)'**
  String get backup_restore_start_button;

  /// No description provided for @backup_share_success_title.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get backup_share_success_title;

  /// No description provided for @backup_share_success_content.
  ///
  /// In en, this message translates to:
  /// **'Backup file shared.'**
  String get backup_share_success_content;

  /// No description provided for @backup_share_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get backup_share_failed_title;

  /// No description provided for @backup_exported_title.
  ///
  /// In en, this message translates to:
  /// **'Exported'**
  String get backup_exported_title;

  /// No description provided for @backup_exported_saved_content.
  ///
  /// In en, this message translates to:
  /// **'Saved to:\\n{path}\\n\\nCompact JSON (~{kb} KB)'**
  String backup_exported_saved_content(Object path, Object kb);

  /// No description provided for @backup_export_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get backup_export_failed_title;

  /// No description provided for @backup_exported_copied_content.
  ///
  /// In en, this message translates to:
  /// **'Copied compact JSON to clipboard (~{kb} KB)'**
  String backup_exported_copied_content(Object kb);

  /// No description provided for @backup_file_picker_title.
  ///
  /// In en, this message translates to:
  /// **'Select backup TXT file'**
  String get backup_file_picker_title;

  /// No description provided for @backup_import_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get backup_import_failed_title;

  /// No description provided for @backup_restore_summary_imported.
  ///
  /// In en, this message translates to:
  /// **'Imported tools: {count}'**
  String backup_restore_summary_imported(Object count);

  /// No description provided for @backup_restore_summary_skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped tools: {count}'**
  String backup_restore_summary_skipped(Object count);

  /// No description provided for @backup_restore_summary_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed tools: {tools}'**
  String backup_restore_summary_failed(Object tools);

  /// No description provided for @backup_restore_complete_title.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get backup_restore_complete_title;

  /// No description provided for @backup_restore_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get backup_restore_failed_title;

  /// No description provided for @backup_confirm_restore_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm restore?'**
  String get backup_confirm_restore_title;

  /// No description provided for @backup_confirm_restore_content.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite local settings and data. It’s recommended to export a backup first.'**
  String get backup_confirm_restore_content;

  /// No description provided for @sync_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Data Sync'**
  String get sync_settings_title;

  /// No description provided for @sync_network_type_section_title.
  ///
  /// In en, this message translates to:
  /// **'Network Type'**
  String get sync_network_type_section_title;

  /// No description provided for @sync_network_public_label.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get sync_network_public_label;

  /// No description provided for @sync_network_private_label.
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get sync_network_private_label;

  /// No description provided for @sync_network_public_hint.
  ///
  /// In en, this message translates to:
  /// **'Public: sync with any network'**
  String get sync_network_public_hint;

  /// No description provided for @sync_network_private_hint.
  ///
  /// In en, this message translates to:
  /// **'Private: only sync on allowed Wi‑Fi (for home/company LAN)'**
  String get sync_network_private_hint;

  /// No description provided for @sync_basic_section_title.
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get sync_basic_section_title;

  /// No description provided for @sync_user_id_label.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get sync_user_id_label;

  /// No description provided for @sync_user_id_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Used to distinguish users on server'**
  String get sync_user_id_placeholder;

  /// No description provided for @sync_server_url_label.
  ///
  /// In en, this message translates to:
  /// **'Server Address'**
  String get sync_server_url_label;

  /// No description provided for @sync_server_url_placeholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. https://sync.example.com or http://127.0.0.1'**
  String get sync_server_url_placeholder;

  /// No description provided for @sync_port_label.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get sync_port_label;

  /// No description provided for @sync_port_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Default 443'**
  String get sync_port_placeholder;

  /// No description provided for @sync_server_url_tip.
  ///
  /// In en, this message translates to:
  /// **'Tip: local deployment (docker/uvicorn) usually uses http + 8080. Add http:// explicitly to avoid TLS handshake errors.'**
  String get sync_server_url_tip;

  /// No description provided for @sync_allowed_wifi_section_title.
  ///
  /// In en, this message translates to:
  /// **'Allowed Wi‑Fi (SSID)'**
  String get sync_allowed_wifi_section_title;

  /// No description provided for @sync_current_wifi_label.
  ///
  /// In en, this message translates to:
  /// **'Current Wi‑Fi: {ssid}'**
  String sync_current_wifi_label(Object ssid);

  /// No description provided for @sync_current_wifi_unknown_hint.
  ///
  /// In en, this message translates to:
  /// **'Current Wi‑Fi: Unknown (tap refresh)'**
  String get sync_current_wifi_unknown_hint;

  /// No description provided for @sync_allowed_wifi_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'No allowed Wi‑Fi configured'**
  String get sync_allowed_wifi_empty_hint;

  /// No description provided for @sync_wifi_ssid_tip.
  ///
  /// In en, this message translates to:
  /// **'Tip: SSID is case‑sensitive. Avoid quotes and leading/trailing spaces.'**
  String get sync_wifi_ssid_tip;

  /// No description provided for @sync_advanced_section_title.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get sync_advanced_section_title;

  /// No description provided for @sync_auto_sync_on_startup_label.
  ///
  /// In en, this message translates to:
  /// **'Auto sync on startup'**
  String get sync_auto_sync_on_startup_label;

  /// No description provided for @sync_section_title.
  ///
  /// In en, this message translates to:
  /// **'Sync'**
  String get sync_section_title;

  /// No description provided for @sync_now_button.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get sync_now_button;

  /// No description provided for @sync_last_sync_label.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {time}'**
  String sync_last_sync_label(Object time);

  /// No description provided for @sync_last_sync_none.
  ///
  /// In en, this message translates to:
  /// **'Last sync: None'**
  String get sync_last_sync_none;

  /// No description provided for @sync_success_label.
  ///
  /// In en, this message translates to:
  /// **'Sync succeeded'**
  String get sync_success_label;

  /// No description provided for @sync_error_details_label.
  ///
  /// In en, this message translates to:
  /// **'Error details:'**
  String get sync_error_details_label;

  /// No description provided for @sync_copy_error_details_button.
  ///
  /// In en, this message translates to:
  /// **'Copy error details'**
  String get sync_copy_error_details_button;

  /// No description provided for @sync_current_network_hint.
  ///
  /// In en, this message translates to:
  /// **'Current network: {network} (Private requires Wi‑Fi)'**
  String sync_current_network_hint(Object network);

  /// No description provided for @sync_wifi_permission_hint.
  ///
  /// In en, this message translates to:
  /// **'Unable to read SSID: location permission not granted (Android requires location to read Wi‑Fi name).'**
  String get sync_wifi_permission_hint;

  /// No description provided for @sync_wifi_ssid_unavailable_hint.
  ///
  /// In en, this message translates to:
  /// **'Connected to Wi‑Fi but SSID unavailable (maybe missing location permission / location disabled / system restriction).'**
  String get sync_wifi_ssid_unavailable_hint;

  /// No description provided for @sync_location_permission_required_title.
  ///
  /// In en, this message translates to:
  /// **'Location permission required'**
  String get sync_location_permission_required_title;

  /// No description provided for @sync_location_permission_required_content.
  ///
  /// In en, this message translates to:
  /// **'Android needs location permission to read current Wi‑Fi SSID. Please allow it and try again.'**
  String get sync_location_permission_required_content;

  /// No description provided for @sync_permission_permanently_denied_title.
  ///
  /// In en, this message translates to:
  /// **'Permission permanently denied'**
  String get sync_permission_permanently_denied_title;

  /// No description provided for @sync_permission_permanently_denied_content.
  ///
  /// In en, this message translates to:
  /// **'Please enable location permission in system settings to read Wi‑Fi SSID.'**
  String get sync_permission_permanently_denied_content;

  /// No description provided for @sync_config_invalid_title.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get sync_config_invalid_title;

  /// No description provided for @sync_config_invalid_content.
  ///
  /// In en, this message translates to:
  /// **'Incomplete config. Check required fields (Private mode requires at least 1 Wi‑Fi).'**
  String get sync_config_invalid_content;

  /// No description provided for @sync_config_saved_title.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get sync_config_saved_title;

  /// No description provided for @sync_config_saved_content.
  ///
  /// In en, this message translates to:
  /// **'Sync settings updated'**
  String get sync_config_saved_content;

  /// No description provided for @sync_finished_title_success.
  ///
  /// In en, this message translates to:
  /// **'Sync complete'**
  String get sync_finished_title_success;

  /// No description provided for @sync_finished_title_failed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get sync_finished_title_failed;

  /// No description provided for @sync_finished_content_success.
  ///
  /// In en, this message translates to:
  /// **'Sync finished.'**
  String get sync_finished_content_success;

  /// No description provided for @sync_finished_content_failed.
  ///
  /// In en, this message translates to:
  /// **'Please check the error details on this page.'**
  String get sync_finished_content_failed;

  /// No description provided for @sync_add_wifi_title.
  ///
  /// In en, this message translates to:
  /// **'Add Wi‑Fi name (SSID)'**
  String get sync_add_wifi_title;

  /// No description provided for @sync_add_wifi_placeholder.
  ///
  /// In en, this message translates to:
  /// **'e.g. MyHomeWifi'**
  String get sync_add_wifi_placeholder;

  /// No description provided for @sync_records_title.
  ///
  /// In en, this message translates to:
  /// **'Sync Records'**
  String get sync_records_title;

  /// No description provided for @sync_details_title.
  ///
  /// In en, this message translates to:
  /// **'Sync Details'**
  String get sync_details_title;

  /// No description provided for @sync_records_config_missing_error.
  ///
  /// In en, this message translates to:
  /// **'Sync config is not set or incomplete. Finish setup before viewing records.'**
  String get sync_records_config_missing_error;

  /// No description provided for @sync_details_config_missing_error.
  ///
  /// In en, this message translates to:
  /// **'Sync config is not set or incomplete. Finish setup before viewing details.'**
  String get sync_details_config_missing_error;

  /// No description provided for @sync_server_label.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get sync_server_label;

  /// No description provided for @sync_user_label.
  ///
  /// In en, this message translates to:
  /// **'User: {userId}'**
  String sync_user_label(Object userId);

  /// No description provided for @sync_open_settings_button.
  ///
  /// In en, this message translates to:
  /// **'Sync Settings'**
  String get sync_open_settings_button;

  /// No description provided for @sync_go_config_button.
  ///
  /// In en, this message translates to:
  /// **'Configure Sync'**
  String get sync_go_config_button;

  /// No description provided for @sync_records_empty_hint.
  ///
  /// In en, this message translates to:
  /// **'No sync records (only records sync actions like client update / server update / rollback).'**
  String get sync_records_empty_hint;

  /// No description provided for @sync_direction_client_to_server.
  ///
  /// In en, this message translates to:
  /// **'Client → Server'**
  String get sync_direction_client_to_server;

  /// No description provided for @sync_direction_server_to_client.
  ///
  /// In en, this message translates to:
  /// **'Server → Client'**
  String get sync_direction_server_to_client;

  /// No description provided for @sync_direction_rollback.
  ///
  /// In en, this message translates to:
  /// **'Server rollback'**
  String get sync_direction_rollback;

  /// No description provided for @sync_direction_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown action'**
  String get sync_direction_unknown;

  /// No description provided for @sync_summary_changed_tools.
  ///
  /// In en, this message translates to:
  /// **'Changed tools {count}'**
  String sync_summary_changed_tools(Object count);

  /// No description provided for @sync_summary_changed_items.
  ///
  /// In en, this message translates to:
  /// **'Changed items {count}{plus}'**
  String sync_summary_changed_items(Object count, Object plus);

  /// No description provided for @sync_summary_no_major_changes.
  ///
  /// In en, this message translates to:
  /// **'No major changes'**
  String get sync_summary_no_major_changes;

  /// No description provided for @sync_action_client_updates_server.
  ///
  /// In en, this message translates to:
  /// **'Client updates server'**
  String get sync_action_client_updates_server;

  /// No description provided for @sync_action_server_updates_client.
  ///
  /// In en, this message translates to:
  /// **'Server updates client'**
  String get sync_action_server_updates_client;

  /// No description provided for @sync_action_rollback_server.
  ///
  /// In en, this message translates to:
  /// **'Rollback (server)'**
  String get sync_action_rollback_server;

  /// No description provided for @sync_action_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get sync_action_unknown;

  /// No description provided for @sync_details_time_label.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}'**
  String sync_details_time_label(Object time);

  /// No description provided for @sync_details_client_updated_at_label.
  ///
  /// In en, this message translates to:
  /// **'Client updated at: {ms}'**
  String sync_details_client_updated_at_label(Object ms);

  /// No description provided for @sync_details_server_updated_at_label.
  ///
  /// In en, this message translates to:
  /// **'Server updated at: {before} → {after}'**
  String sync_details_server_updated_at_label(Object before, Object after);

  /// No description provided for @sync_details_server_revision_label.
  ///
  /// In en, this message translates to:
  /// **'Server revision: {before} → {after}'**
  String sync_details_server_revision_label(Object before, Object after);

  /// No description provided for @sync_rollback_section_title.
  ///
  /// In en, this message translates to:
  /// **'Version Restore'**
  String get sync_rollback_section_title;

  /// No description provided for @sync_rollback_section_hint.
  ///
  /// In en, this message translates to:
  /// **'You can restore data to the state before this record.'**
  String get sync_rollback_section_hint;

  /// No description provided for @sync_rollback_to_version_title.
  ///
  /// In en, this message translates to:
  /// **'Restore to this version'**
  String get sync_rollback_to_version_title;

  /// No description provided for @sync_rollback_to_version_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Rollback both cloud and local'**
  String get sync_rollback_to_version_subtitle;

  /// No description provided for @sync_rollback_local_only_title.
  ///
  /// In en, this message translates to:
  /// **'Restore local only'**
  String get sync_rollback_local_only_title;

  /// No description provided for @sync_rollback_local_only_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Local preview only; does not affect cloud'**
  String get sync_rollback_local_only_subtitle;

  /// No description provided for @sync_rollback_target_revision.
  ///
  /// In en, this message translates to:
  /// **'Revision {revision}'**
  String sync_rollback_target_revision(Object revision);

  /// No description provided for @sync_rollback_no_target.
  ///
  /// In en, this message translates to:
  /// **'No restorable version'**
  String get sync_rollback_no_target;

  /// No description provided for @sync_not_configured_title.
  ///
  /// In en, this message translates to:
  /// **'Sync not configured'**
  String get sync_not_configured_title;

  /// No description provided for @sync_not_configured_content.
  ///
  /// In en, this message translates to:
  /// **'Please set server address/port and user ID before rollback.'**
  String get sync_not_configured_content;

  /// No description provided for @sync_network_precheck_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Network precheck failed'**
  String get sync_network_precheck_failed_title;

  /// No description provided for @sync_confirm_rollback_server_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm rollback server?'**
  String get sync_confirm_rollback_server_title;

  /// No description provided for @sync_confirm_rollback_server_content.
  ///
  /// In en, this message translates to:
  /// **'Rollback server to {revision} and overwrite local data. This will create a new server revision.'**
  String sync_confirm_rollback_server_content(Object revision);

  /// No description provided for @sync_confirm_rollback_server_confirm.
  ///
  /// In en, this message translates to:
  /// **'Rollback'**
  String get sync_confirm_rollback_server_confirm;

  /// No description provided for @sync_rollback_done_title.
  ///
  /// In en, this message translates to:
  /// **'Rollback complete'**
  String get sync_rollback_done_title;

  /// No description provided for @sync_rollback_done_content.
  ///
  /// In en, this message translates to:
  /// **'Rolled back to {revision} and overwrote local data. New server revision: {newRevision}'**
  String sync_rollback_done_content(Object revision, Object newRevision);

  /// No description provided for @sync_rollback_done_partial_content.
  ///
  /// In en, this message translates to:
  /// **'Server rolled back, but some tools failed to import:\\n{error}'**
  String sync_rollback_done_partial_content(Object error);

  /// No description provided for @sync_rollback_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Rollback failed'**
  String get sync_rollback_failed_title;

  /// No description provided for @sync_confirm_rollback_local_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm local-only restore?'**
  String get sync_confirm_rollback_local_title;

  /// No description provided for @sync_confirm_rollback_local_content.
  ///
  /// In en, this message translates to:
  /// **'Local data will be overwritten with server snapshot {revision}, but the cloud current revision will not change.\\nNote: On next sync, local may be overwritten by cloud (use “Rollback server and overwrite local” instead).'**
  String sync_confirm_rollback_local_content(Object revision);

  /// No description provided for @sync_confirm_rollback_local_confirm.
  ///
  /// In en, this message translates to:
  /// **'Overwrite local'**
  String get sync_confirm_rollback_local_confirm;

  /// No description provided for @sync_overwrite_local_done_title.
  ///
  /// In en, this message translates to:
  /// **'Local overwritten'**
  String get sync_overwrite_local_done_title;

  /// No description provided for @sync_overwrite_local_done_content.
  ///
  /// In en, this message translates to:
  /// **'Local overwritten to {revision}'**
  String sync_overwrite_local_done_content(Object revision);

  /// No description provided for @sync_overwrite_local_done_partial_content.
  ///
  /// In en, this message translates to:
  /// **'Some tools failed to import:\\n{error}'**
  String sync_overwrite_local_done_partial_content(Object error);

  /// No description provided for @sync_overwrite_local_failed_title.
  ///
  /// In en, this message translates to:
  /// **'Overwrite failed'**
  String get sync_overwrite_local_failed_title;

  /// No description provided for @sync_diff_none.
  ///
  /// In en, this message translates to:
  /// **'No diff details'**
  String get sync_diff_none;

  /// No description provided for @sync_diff_format_error.
  ///
  /// In en, this message translates to:
  /// **'Diff format error'**
  String get sync_diff_format_error;

  /// No description provided for @sync_diff_no_substantive.
  ///
  /// In en, this message translates to:
  /// **'No substantive changes (only ignored length changes)'**
  String get sync_diff_no_substantive;

  /// No description provided for @sync_diff_unknown_item.
  ///
  /// In en, this message translates to:
  /// **'• Unknown diff item'**
  String get sync_diff_unknown_item;

  /// No description provided for @tool_tag_manager_name.
  ///
  /// In en, this message translates to:
  /// **'Tag Manager'**
  String get tool_tag_manager_name;

  /// No description provided for @tool_app_config_name.
  ///
  /// In en, this message translates to:
  /// **'App Config'**
  String get tool_app_config_name;

  /// No description provided for @tag_category_location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get tag_category_location;

  /// No description provided for @tag_category_item_type.
  ///
  /// In en, this message translates to:
  /// **'Item type'**
  String get tag_category_item_type;

  /// No description provided for @tag_category_dish_type.
  ///
  /// In en, this message translates to:
  /// **'Dish type'**
  String get tag_category_dish_type;

  /// No description provided for @tag_category_ingredient.
  ///
  /// In en, this message translates to:
  /// **'Ingredient'**
  String get tag_category_ingredient;

  /// No description provided for @tag_category_sauce.
  ///
  /// In en, this message translates to:
  /// **'Sauce'**
  String get tag_category_sauce;

  /// No description provided for @tag_category_affiliation.
  ///
  /// In en, this message translates to:
  /// **'Affiliation'**
  String get tag_category_affiliation;

  /// No description provided for @tag_category_flavor.
  ///
  /// In en, this message translates to:
  /// **'Flavor'**
  String get tag_category_flavor;

  /// No description provided for @tag_category_meal_slot.
  ///
  /// In en, this message translates to:
  /// **'Meal slot'**
  String get tag_category_meal_slot;

  /// No description provided for @sync_diff_label_added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get sync_diff_label_added;

  /// No description provided for @sync_diff_label_removed.
  ///
  /// In en, this message translates to:
  /// **'Removed'**
  String get sync_diff_label_removed;

  /// No description provided for @sync_diff_label_modified.
  ///
  /// In en, this message translates to:
  /// **'Modified'**
  String get sync_diff_label_modified;

  /// No description provided for @sync_diff_label_type_changed.
  ///
  /// In en, this message translates to:
  /// **'Type changed'**
  String get sync_diff_label_type_changed;

  /// No description provided for @sync_diff_content_changed.
  ///
  /// In en, this message translates to:
  /// **'Content changed'**
  String get sync_diff_content_changed;

  /// No description provided for @sync_diff_added_data.
  ///
  /// In en, this message translates to:
  /// **'Data added'**
  String get sync_diff_added_data;

  /// No description provided for @sync_diff_removed_data.
  ///
  /// In en, this message translates to:
  /// **'Data removed'**
  String get sync_diff_removed_data;

  /// No description provided for @sync_diff_detail_tag_added.
  ///
  /// In en, this message translates to:
  /// **'Added {toolName} {categoryName} tag: 【{tagName}】'**
  String sync_diff_detail_tag_added(
    Object toolName,
    Object categoryName,
    Object tagName,
  );

  /// No description provided for @sync_diff_detail_tag_removed.
  ///
  /// In en, this message translates to:
  /// **'Removed {toolName} {categoryName} tag: 【{tagName}】'**
  String sync_diff_detail_tag_removed(
    Object toolName,
    Object categoryName,
    Object tagName,
  );

  /// No description provided for @sync_diff_detail_named_added.
  ///
  /// In en, this message translates to:
  /// **'Added: 【{name}】'**
  String sync_diff_detail_named_added(Object name);

  /// No description provided for @sync_diff_detail_named_removed.
  ///
  /// In en, this message translates to:
  /// **'Removed: 【{name}】'**
  String sync_diff_detail_named_removed(Object name);

  /// No description provided for @sync_diff_detail_titled_added.
  ///
  /// In en, this message translates to:
  /// **'Added: 【{title}】'**
  String sync_diff_detail_titled_added(Object title);

  /// No description provided for @sync_diff_detail_titled_removed.
  ///
  /// In en, this message translates to:
  /// **'Removed: 【{title}】'**
  String sync_diff_detail_titled_removed(Object title);

  /// No description provided for @sync_diff_path_item.
  ///
  /// In en, this message translates to:
  /// **'Item {index}'**
  String sync_diff_path_item(Object index);

  /// No description provided for @sync_auto_sync_success_toast.
  ///
  /// In en, this message translates to:
  /// **'Auto sync succeeded'**
  String get sync_auto_sync_success_toast;

  /// No description provided for @sync_auto_sync_failed_toast.
  ///
  /// In en, this message translates to:
  /// **'Auto sync failed: {error}'**
  String sync_auto_sync_failed_toast(Object error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'US':
            return AppLocalizationsEnUs();
        }
        break;
      }
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'CN':
            return AppLocalizationsZhCn();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
