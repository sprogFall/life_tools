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

  @override
  String get common_refresh => 'Refresh';

  @override
  String get common_export => 'Export';

  @override
  String get common_restore => 'Restore';

  @override
  String get common_clear => 'Clear';

  @override
  String get common_add => 'Add';

  @override
  String get common_continue => 'Continue';

  @override
  String get common_load_more => 'Load More';

  @override
  String get common_not_configured => 'Not configured';

  @override
  String get common_go_settings => 'Open Settings';

  @override
  String get network_status_wifi => 'Wi‑Fi';

  @override
  String get network_status_mobile => 'Mobile';

  @override
  String get network_status_offline => 'Offline';

  @override
  String get network_status_unknown => 'Unknown';

  @override
  String get backup_restore_title => 'Backup & Restore';

  @override
  String get backup_received_title => 'Backup received';

  @override
  String get backup_received_content =>
      'Backup content has been filled in. Review it and tap \"Start Restore\".';

  @override
  String get backup_export_hint_intro =>
      'Export the following as JSON (for large data, export as a TXT file):';

  @override
  String get backup_export_hint_items =>
      '1) AI settings (Base URL / model / params)\\n2) Sync settings (server / network mode, etc.)\\n3) Object store settings (Qiniu / local)\\n4) Tool management (default tool / home visibility / tool order, etc.)\\n5) Tool data (exported via ToolSyncProvider)';

  @override
  String get backup_include_sensitive_label =>
      'Include sensitive info (AI key / sync token / storage keys)';

  @override
  String get backup_include_sensitive_on_hint =>
      'Enabled by default: the export will include keys/tokens. Only share with trusted recipients.';

  @override
  String get backup_include_sensitive_off_hint =>
      'Disabled: keys/tokens won’t be exported (safer; you can re-enter them in Settings after restore).';

  @override
  String get backup_export_share_button => 'Export & Share';

  @override
  String get backup_export_save_txt_button => 'Save as TXT';

  @override
  String get backup_export_copy_clipboard_button => 'Copy JSON to Clipboard';

  @override
  String get backup_restore_hint =>
      'Paste JSON and overwrite local settings & data (be careful; export a backup first).';

  @override
  String get backup_restore_placeholder => 'Paste backup JSON here…';

  @override
  String get backup_restore_paste_button => 'Paste from Clipboard';

  @override
  String get backup_restore_import_txt_button => 'Import from TXT';

  @override
  String get backup_restore_start_button => 'Start Restore (Overwrite Local)';

  @override
  String get backup_share_success_title => 'Shared';

  @override
  String get backup_share_success_content => 'Backup file shared.';

  @override
  String get backup_share_failed_title => 'Share failed';

  @override
  String get backup_exported_title => 'Exported';

  @override
  String backup_exported_saved_content(Object path, Object kb) {
    return 'Saved to:\\n$path\\n\\nCompact JSON (~$kb KB)';
  }

  @override
  String get backup_export_failed_title => 'Export failed';

  @override
  String backup_exported_copied_content(Object kb) {
    return 'Copied compact JSON to clipboard (~$kb KB)';
  }

  @override
  String get backup_file_picker_title => 'Select backup TXT file';

  @override
  String get backup_import_failed_title => 'Import failed';

  @override
  String backup_restore_summary_imported(Object count) {
    return 'Imported tools: $count';
  }

  @override
  String backup_restore_summary_skipped(Object count) {
    return 'Skipped tools: $count';
  }

  @override
  String backup_restore_summary_failed(Object tools) {
    return 'Failed tools: $tools';
  }

  @override
  String get backup_restore_complete_title => 'Restore complete';

  @override
  String get backup_restore_failed_title => 'Restore failed';

  @override
  String get backup_confirm_restore_title => 'Confirm restore?';

  @override
  String get backup_confirm_restore_content =>
      'This will overwrite local settings and data. It’s recommended to export a backup first.';

  @override
  String get sync_settings_title => 'Data Sync';

  @override
  String get sync_network_type_section_title => 'Network Type';

  @override
  String get sync_network_public_label => 'Public';

  @override
  String get sync_network_private_label => 'Private';

  @override
  String get sync_network_public_hint => 'Public: sync with any network';

  @override
  String get sync_network_private_hint =>
      'Private: only sync on allowed Wi‑Fi (for home/company LAN)';

  @override
  String get sync_basic_section_title => 'Basic Settings';

  @override
  String get sync_user_id_label => 'User ID';

  @override
  String get sync_user_id_placeholder => 'Used to distinguish users on server';

  @override
  String get sync_server_url_label => 'Server Address';

  @override
  String get sync_server_url_placeholder =>
      'e.g. https://sync.example.com or http://127.0.0.1';

  @override
  String get sync_port_label => 'Port';

  @override
  String get sync_port_placeholder => 'Default 443';

  @override
  String get sync_server_url_tip =>
      'Tip: local deployment (docker/uvicorn) usually uses http + 8080. Add http:// explicitly to avoid TLS handshake errors.';

  @override
  String get sync_allowed_wifi_section_title => 'Allowed Wi‑Fi (SSID)';

  @override
  String sync_current_wifi_label(Object ssid) {
    return 'Current Wi‑Fi: $ssid';
  }

  @override
  String get sync_current_wifi_unknown_hint =>
      'Current Wi‑Fi: Unknown (tap refresh)';

  @override
  String get sync_allowed_wifi_empty_hint => 'No allowed Wi‑Fi configured';

  @override
  String get sync_wifi_ssid_tip =>
      'Tip: SSID is case‑sensitive. Avoid quotes and leading/trailing spaces.';

  @override
  String get sync_advanced_section_title => 'Advanced';

  @override
  String get sync_auto_sync_on_startup_label => 'Auto sync on startup';

  @override
  String get sync_section_title => 'Sync';

  @override
  String get sync_now_button => 'Sync Now';

  @override
  String sync_last_sync_label(Object time) {
    return 'Last sync: $time';
  }

  @override
  String get sync_last_sync_none => 'Last sync: None';

  @override
  String get sync_success_label => 'Sync succeeded';

  @override
  String get sync_error_details_label => 'Error details:';

  @override
  String get sync_copy_error_details_button => 'Copy error details';

  @override
  String sync_current_network_hint(Object network) {
    return 'Current network: $network (Private requires Wi‑Fi)';
  }

  @override
  String get sync_wifi_permission_hint =>
      'Unable to read SSID: location permission not granted (Android requires location to read Wi‑Fi name).';

  @override
  String get sync_wifi_ssid_unavailable_hint =>
      'Connected to Wi‑Fi but SSID unavailable (maybe missing location permission / location disabled / system restriction).';

  @override
  String get sync_location_permission_required_title =>
      'Location permission required';

  @override
  String get sync_location_permission_required_content =>
      'Android needs location permission to read current Wi‑Fi SSID. Please allow it and try again.';

  @override
  String get sync_permission_permanently_denied_title =>
      'Permission permanently denied';

  @override
  String get sync_permission_permanently_denied_content =>
      'Please enable location permission in system settings to read Wi‑Fi SSID.';

  @override
  String get sync_config_invalid_title => 'Tip';

  @override
  String get sync_config_invalid_content =>
      'Incomplete config. Check required fields (Private mode requires at least 1 Wi‑Fi).';

  @override
  String get sync_config_saved_title => 'Saved';

  @override
  String get sync_config_saved_content => 'Sync settings updated';

  @override
  String get sync_finished_title_success => 'Sync complete';

  @override
  String get sync_finished_title_failed => 'Sync failed';

  @override
  String get sync_finished_content_success => 'Sync finished.';

  @override
  String get sync_finished_content_failed =>
      'Please check the error details on this page.';

  @override
  String get sync_add_wifi_title => 'Add Wi‑Fi name (SSID)';

  @override
  String get sync_add_wifi_placeholder => 'e.g. MyHomeWifi';

  @override
  String get sync_records_title => 'Sync Records';

  @override
  String get sync_details_title => 'Sync Details';

  @override
  String get sync_records_config_missing_error =>
      'Sync config is not set or incomplete. Finish setup before viewing records.';

  @override
  String get sync_details_config_missing_error =>
      'Sync config is not set or incomplete. Finish setup before viewing details.';

  @override
  String get sync_server_label => 'Server';

  @override
  String sync_user_label(Object userId) {
    return 'User: $userId';
  }

  @override
  String get sync_open_settings_button => 'Sync Settings';

  @override
  String get sync_go_config_button => 'Configure Sync';

  @override
  String get sync_records_empty_hint =>
      'No sync records (only records sync actions like client update / server update / rollback).';

  @override
  String get sync_direction_client_to_server => 'Client → Server';

  @override
  String get sync_direction_server_to_client => 'Server → Client';

  @override
  String get sync_direction_rollback => 'Server rollback';

  @override
  String get sync_direction_unknown => 'Unknown action';

  @override
  String sync_summary_changed_tools(Object count) {
    return 'Changed tools $count';
  }

  @override
  String sync_summary_changed_items(Object count, Object plus) {
    return 'Changed items $count$plus';
  }

  @override
  String get sync_summary_no_major_changes => 'No major changes';

  @override
  String get sync_action_client_updates_server => 'Client updates server';

  @override
  String get sync_action_server_updates_client => 'Server updates client';

  @override
  String get sync_action_rollback_server => 'Rollback (server)';

  @override
  String get sync_action_unknown => 'Unknown';

  @override
  String sync_details_time_label(Object time) {
    return 'Time: $time';
  }

  @override
  String sync_details_client_updated_at_label(Object ms) {
    return 'Client updated at: $ms';
  }

  @override
  String sync_details_server_updated_at_label(Object before, Object after) {
    return 'Server updated at: $before → $after';
  }

  @override
  String sync_details_server_revision_label(Object before, Object after) {
    return 'Server revision: $before → $after';
  }

  @override
  String get sync_rollback_section_title => 'Version Restore';

  @override
  String get sync_rollback_section_hint =>
      'You can restore data to the state before this record.';

  @override
  String get sync_rollback_to_version_title => 'Restore to this version';

  @override
  String get sync_rollback_to_version_subtitle =>
      'Rollback both cloud and local';

  @override
  String get sync_rollback_local_only_title => 'Restore local only';

  @override
  String get sync_rollback_local_only_subtitle =>
      'Local preview only; does not affect cloud';

  @override
  String sync_rollback_target_revision(Object revision) {
    return 'Revision $revision';
  }

  @override
  String get sync_rollback_no_target => 'No restorable version';

  @override
  String get sync_not_configured_title => 'Sync not configured';

  @override
  String get sync_not_configured_content =>
      'Please set server address/port and user ID before rollback.';

  @override
  String get sync_network_precheck_failed_title => 'Network precheck failed';

  @override
  String get sync_confirm_rollback_server_title => 'Confirm rollback server?';

  @override
  String sync_confirm_rollback_server_content(Object revision) {
    return 'Rollback server to $revision and overwrite local data. This will create a new server revision.';
  }

  @override
  String get sync_confirm_rollback_server_confirm => 'Rollback';

  @override
  String get sync_rollback_done_title => 'Rollback complete';

  @override
  String sync_rollback_done_content(Object revision, Object newRevision) {
    return 'Rolled back to $revision and overwrote local data. New server revision: $newRevision';
  }

  @override
  String sync_rollback_done_partial_content(Object error) {
    return 'Server rolled back, but some tools failed to import:\\n$error';
  }

  @override
  String get sync_rollback_failed_title => 'Rollback failed';

  @override
  String get sync_confirm_rollback_local_title => 'Confirm local-only restore?';

  @override
  String sync_confirm_rollback_local_content(Object revision) {
    return 'Local data will be overwritten with server snapshot $revision, but the cloud current revision will not change.\\nNote: On next sync, local may be overwritten by cloud (use “Rollback server and overwrite local” instead).';
  }

  @override
  String get sync_confirm_rollback_local_confirm => 'Overwrite local';

  @override
  String get sync_overwrite_local_done_title => 'Local overwritten';

  @override
  String sync_overwrite_local_done_content(Object revision) {
    return 'Local overwritten to $revision';
  }

  @override
  String sync_overwrite_local_done_partial_content(Object error) {
    return 'Some tools failed to import:\\n$error';
  }

  @override
  String get sync_overwrite_local_failed_title => 'Overwrite failed';

  @override
  String get sync_diff_none => 'No diff details';

  @override
  String get sync_diff_format_error => 'Diff format error';

  @override
  String get sync_diff_no_substantive =>
      'No substantive changes (only ignored length changes)';

  @override
  String get sync_diff_unknown_item => '• Unknown diff item';

  @override
  String get tool_tag_manager_name => 'Tag Manager';

  @override
  String get tool_app_config_name => 'App Config';

  @override
  String get tag_category_location => 'Location';

  @override
  String get tag_category_item_type => 'Item type';

  @override
  String get tag_category_dish_type => 'Dish type';

  @override
  String get tag_category_ingredient => 'Ingredient';

  @override
  String get tag_category_sauce => 'Sauce';

  @override
  String get tag_category_affiliation => 'Affiliation';

  @override
  String get tag_category_flavor => 'Flavor';

  @override
  String get tag_category_meal_slot => 'Meal slot';

  @override
  String get sync_diff_label_added => 'Added';

  @override
  String get sync_diff_label_removed => 'Removed';

  @override
  String get sync_diff_label_modified => 'Modified';

  @override
  String get sync_diff_label_type_changed => 'Type changed';

  @override
  String get sync_diff_content_changed => 'Content changed';

  @override
  String get sync_diff_added_data => 'Data added';

  @override
  String get sync_diff_removed_data => 'Data removed';

  @override
  String sync_diff_detail_tag_added(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return 'Added $toolName $categoryName tag: 【$tagName】';
  }

  @override
  String sync_diff_detail_tag_removed(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return 'Removed $toolName $categoryName tag: 【$tagName】';
  }

  @override
  String sync_diff_detail_named_added(Object name) {
    return 'Added: 【$name】';
  }

  @override
  String sync_diff_detail_named_removed(Object name) {
    return 'Removed: 【$name】';
  }

  @override
  String sync_diff_detail_titled_added(Object title) {
    return 'Added: 【$title】';
  }

  @override
  String sync_diff_detail_titled_removed(Object title) {
    return 'Removed: 【$title】';
  }

  @override
  String sync_diff_path_item(Object index) {
    return 'Item $index';
  }

  @override
  String get sync_auto_sync_success_toast => 'Auto sync succeeded';

  @override
  String sync_auto_sync_failed_toast(Object error) {
    return 'Auto sync failed: $error';
  }

  @override
  String get ai_settings_title => 'AI Settings';

  @override
  String get ai_settings_openai_section_title => 'OpenAI-Compatible Settings';

  @override
  String get ai_settings_base_url_label => 'Base URL';

  @override
  String get ai_settings_base_url_placeholder => 'https://api.openai.com/v1';

  @override
  String get ai_settings_api_key_label => 'API Key';

  @override
  String get ai_settings_api_key_placeholder => 'sk-...';

  @override
  String get ai_settings_model_label => 'Model';

  @override
  String get ai_settings_model_placeholder => 'gpt-4o-mini';

  @override
  String get ai_settings_temperature_label => 'Temperature';

  @override
  String get ai_settings_temperature_placeholder => '0.7';

  @override
  String get ai_settings_max_tokens_label => 'Max Tokens';

  @override
  String get ai_settings_max_tokens_placeholder => '1024';

  @override
  String get ai_settings_test_button => 'Test Connection';

  @override
  String get ai_settings_testing_button => 'Testing...';

  @override
  String get ai_settings_tips_section_title => 'Notes';

  @override
  String get ai_settings_tips_content =>
      '1. Base URL can be a domain (e.g. https://example.com) or include /v1.\\n2. Uses OpenAI-compatible endpoint: /v1/chat/completions.\\n3. API key is stored locally (SharedPreferences).';

  @override
  String get ai_settings_danger_section_title => 'Danger Zone';

  @override
  String get ai_settings_clear_button => 'Clear AI Settings';

  @override
  String get ai_settings_invalid_title => 'Tip';

  @override
  String get ai_settings_invalid_content =>
      'Check your settings: Base URL / API Key / Model must not be empty; temperature must be 0–2; Max Tokens must be > 0.';

  @override
  String get ai_settings_saved_title => 'Saved';

  @override
  String ai_settings_saved_content(Object model) {
    return 'Current model: $model';
  }

  @override
  String get ai_settings_test_invalid_content =>
      'Please enter a valid AI configuration before testing.';

  @override
  String get ai_settings_testing_loading_title => 'Testing';

  @override
  String get ai_settings_test_result_title => 'Test Result';

  @override
  String get ai_settings_test_failed_title => 'Test Failed';

  @override
  String get ai_settings_clear_confirm_title => 'Confirm clear?';

  @override
  String get ai_settings_clear_confirm_content =>
      'After clearing, AI features will be unavailable until you configure again.';

  @override
  String get ai_settings_clear_confirm_button => 'Clear';

  @override
  String get obj_store_settings_title => 'Object Storage';

  @override
  String get obj_store_settings_type_section_title => 'Storage Type';

  @override
  String get obj_store_settings_type_none_label => 'None';

  @override
  String get obj_store_settings_type_local_label => 'Local';

  @override
  String get obj_store_settings_type_qiniu_label => 'Qiniu';

  @override
  String get obj_store_settings_type_data_capsule_label => 'Data Capsule';
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

  @override
  String get common_refresh => 'Refresh';

  @override
  String get common_export => 'Export';

  @override
  String get common_restore => 'Restore';

  @override
  String get common_clear => 'Clear';

  @override
  String get common_add => 'Add';

  @override
  String get common_continue => 'Continue';

  @override
  String get common_load_more => 'Load More';

  @override
  String get common_not_configured => 'Not configured';

  @override
  String get common_go_settings => 'Open Settings';

  @override
  String get network_status_wifi => 'Wi‑Fi';

  @override
  String get network_status_mobile => 'Mobile';

  @override
  String get network_status_offline => 'Offline';

  @override
  String get network_status_unknown => 'Unknown';

  @override
  String get backup_restore_title => 'Backup & Restore';

  @override
  String get backup_received_title => 'Backup received';

  @override
  String get backup_received_content =>
      'Backup content has been filled in. Review it and tap \"Start Restore\".';

  @override
  String get backup_export_hint_intro =>
      'Export the following as JSON (for large data, export as a TXT file):';

  @override
  String get backup_export_hint_items =>
      '1) AI settings (Base URL / model / params)\\n2) Sync settings (server / network mode, etc.)\\n3) Object store settings (Qiniu / local)\\n4) Tool management (default tool / home visibility / tool order, etc.)\\n5) Tool data (exported via ToolSyncProvider)';

  @override
  String get backup_include_sensitive_label =>
      'Include sensitive info (AI key / sync token / storage keys)';

  @override
  String get backup_include_sensitive_on_hint =>
      'Enabled by default: the export will include keys/tokens. Only share with trusted recipients.';

  @override
  String get backup_include_sensitive_off_hint =>
      'Disabled: keys/tokens won’t be exported (safer; you can re-enter them in Settings after restore).';

  @override
  String get backup_export_share_button => 'Export & Share';

  @override
  String get backup_export_save_txt_button => 'Save as TXT';

  @override
  String get backup_export_copy_clipboard_button => 'Copy JSON to Clipboard';

  @override
  String get backup_restore_hint =>
      'Paste JSON and overwrite local settings & data (be careful; export a backup first).';

  @override
  String get backup_restore_placeholder => 'Paste backup JSON here…';

  @override
  String get backup_restore_paste_button => 'Paste from Clipboard';

  @override
  String get backup_restore_import_txt_button => 'Import from TXT';

  @override
  String get backup_restore_start_button => 'Start Restore (Overwrite Local)';

  @override
  String get backup_share_success_title => 'Shared';

  @override
  String get backup_share_success_content => 'Backup file shared.';

  @override
  String get backup_share_failed_title => 'Share failed';

  @override
  String get backup_exported_title => 'Exported';

  @override
  String backup_exported_saved_content(Object path, Object kb) {
    return 'Saved to:\\n$path\\n\\nCompact JSON (~$kb KB)';
  }

  @override
  String get backup_export_failed_title => 'Export failed';

  @override
  String backup_exported_copied_content(Object kb) {
    return 'Copied compact JSON to clipboard (~$kb KB)';
  }

  @override
  String get backup_file_picker_title => 'Select backup TXT file';

  @override
  String get backup_import_failed_title => 'Import failed';

  @override
  String backup_restore_summary_imported(Object count) {
    return 'Imported tools: $count';
  }

  @override
  String backup_restore_summary_skipped(Object count) {
    return 'Skipped tools: $count';
  }

  @override
  String backup_restore_summary_failed(Object tools) {
    return 'Failed tools: $tools';
  }

  @override
  String get backup_restore_complete_title => 'Restore complete';

  @override
  String get backup_restore_failed_title => 'Restore failed';

  @override
  String get backup_confirm_restore_title => 'Confirm restore?';

  @override
  String get backup_confirm_restore_content =>
      'This will overwrite local settings and data. It’s recommended to export a backup first.';

  @override
  String get sync_settings_title => 'Data Sync';

  @override
  String get sync_network_type_section_title => 'Network Type';

  @override
  String get sync_network_public_label => 'Public';

  @override
  String get sync_network_private_label => 'Private';

  @override
  String get sync_network_public_hint => 'Public: sync with any network';

  @override
  String get sync_network_private_hint =>
      'Private: only sync on allowed Wi‑Fi (for home/company LAN)';

  @override
  String get sync_basic_section_title => 'Basic Settings';

  @override
  String get sync_user_id_label => 'User ID';

  @override
  String get sync_user_id_placeholder => 'Used to distinguish users on server';

  @override
  String get sync_server_url_label => 'Server Address';

  @override
  String get sync_server_url_placeholder =>
      'e.g. https://sync.example.com or http://127.0.0.1';

  @override
  String get sync_port_label => 'Port';

  @override
  String get sync_port_placeholder => 'Default 443';

  @override
  String get sync_server_url_tip =>
      'Tip: local deployment (docker/uvicorn) usually uses http + 8080. Add http:// explicitly to avoid TLS handshake errors.';

  @override
  String get sync_allowed_wifi_section_title => 'Allowed Wi‑Fi (SSID)';

  @override
  String sync_current_wifi_label(Object ssid) {
    return 'Current Wi‑Fi: $ssid';
  }

  @override
  String get sync_current_wifi_unknown_hint =>
      'Current Wi‑Fi: Unknown (tap refresh)';

  @override
  String get sync_allowed_wifi_empty_hint => 'No allowed Wi‑Fi configured';

  @override
  String get sync_wifi_ssid_tip =>
      'Tip: SSID is case‑sensitive. Avoid quotes and leading/trailing spaces.';

  @override
  String get sync_advanced_section_title => 'Advanced';

  @override
  String get sync_auto_sync_on_startup_label => 'Auto sync on startup';

  @override
  String get sync_section_title => 'Sync';

  @override
  String get sync_now_button => 'Sync Now';

  @override
  String sync_last_sync_label(Object time) {
    return 'Last sync: $time';
  }

  @override
  String get sync_last_sync_none => 'Last sync: None';

  @override
  String get sync_success_label => 'Sync succeeded';

  @override
  String get sync_error_details_label => 'Error details:';

  @override
  String get sync_copy_error_details_button => 'Copy error details';

  @override
  String sync_current_network_hint(Object network) {
    return 'Current network: $network (Private requires Wi‑Fi)';
  }

  @override
  String get sync_wifi_permission_hint =>
      'Unable to read SSID: location permission not granted (Android requires location to read Wi‑Fi name).';

  @override
  String get sync_wifi_ssid_unavailable_hint =>
      'Connected to Wi‑Fi but SSID unavailable (maybe missing location permission / location disabled / system restriction).';

  @override
  String get sync_location_permission_required_title =>
      'Location permission required';

  @override
  String get sync_location_permission_required_content =>
      'Android needs location permission to read current Wi‑Fi SSID. Please allow it and try again.';

  @override
  String get sync_permission_permanently_denied_title =>
      'Permission permanently denied';

  @override
  String get sync_permission_permanently_denied_content =>
      'Please enable location permission in system settings to read Wi‑Fi SSID.';

  @override
  String get sync_config_invalid_title => 'Tip';

  @override
  String get sync_config_invalid_content =>
      'Incomplete config. Check required fields (Private mode requires at least 1 Wi‑Fi).';

  @override
  String get sync_config_saved_title => 'Saved';

  @override
  String get sync_config_saved_content => 'Sync settings updated';

  @override
  String get sync_finished_title_success => 'Sync complete';

  @override
  String get sync_finished_title_failed => 'Sync failed';

  @override
  String get sync_finished_content_success => 'Sync finished.';

  @override
  String get sync_finished_content_failed =>
      'Please check the error details on this page.';

  @override
  String get sync_add_wifi_title => 'Add Wi‑Fi name (SSID)';

  @override
  String get sync_add_wifi_placeholder => 'e.g. MyHomeWifi';

  @override
  String get sync_records_title => 'Sync Records';

  @override
  String get sync_details_title => 'Sync Details';

  @override
  String get sync_records_config_missing_error =>
      'Sync config is not set or incomplete. Finish setup before viewing records.';

  @override
  String get sync_details_config_missing_error =>
      'Sync config is not set or incomplete. Finish setup before viewing details.';

  @override
  String get sync_server_label => 'Server';

  @override
  String sync_user_label(Object userId) {
    return 'User: $userId';
  }

  @override
  String get sync_open_settings_button => 'Sync Settings';

  @override
  String get sync_go_config_button => 'Configure Sync';

  @override
  String get sync_records_empty_hint =>
      'No sync records (only records sync actions like client update / server update / rollback).';

  @override
  String get sync_direction_client_to_server => 'Client → Server';

  @override
  String get sync_direction_server_to_client => 'Server → Client';

  @override
  String get sync_direction_rollback => 'Server rollback';

  @override
  String get sync_direction_unknown => 'Unknown action';

  @override
  String sync_summary_changed_tools(Object count) {
    return 'Changed tools $count';
  }

  @override
  String sync_summary_changed_items(Object count, Object plus) {
    return 'Changed items $count$plus';
  }

  @override
  String get sync_summary_no_major_changes => 'No major changes';

  @override
  String get sync_action_client_updates_server => 'Client updates server';

  @override
  String get sync_action_server_updates_client => 'Server updates client';

  @override
  String get sync_action_rollback_server => 'Rollback (server)';

  @override
  String get sync_action_unknown => 'Unknown';

  @override
  String sync_details_time_label(Object time) {
    return 'Time: $time';
  }

  @override
  String sync_details_client_updated_at_label(Object ms) {
    return 'Client updated at: $ms';
  }

  @override
  String sync_details_server_updated_at_label(Object before, Object after) {
    return 'Server updated at: $before → $after';
  }

  @override
  String sync_details_server_revision_label(Object before, Object after) {
    return 'Server revision: $before → $after';
  }

  @override
  String get sync_rollback_section_title => 'Version Restore';

  @override
  String get sync_rollback_section_hint =>
      'You can restore data to the state before this record.';

  @override
  String get sync_rollback_to_version_title => 'Restore to this version';

  @override
  String get sync_rollback_to_version_subtitle =>
      'Rollback both cloud and local';

  @override
  String get sync_rollback_local_only_title => 'Restore local only';

  @override
  String get sync_rollback_local_only_subtitle =>
      'Local preview only; does not affect cloud';

  @override
  String sync_rollback_target_revision(Object revision) {
    return 'Revision $revision';
  }

  @override
  String get sync_rollback_no_target => 'No restorable version';

  @override
  String get sync_not_configured_title => 'Sync not configured';

  @override
  String get sync_not_configured_content =>
      'Please set server address/port and user ID before rollback.';

  @override
  String get sync_network_precheck_failed_title => 'Network precheck failed';

  @override
  String get sync_confirm_rollback_server_title => 'Confirm rollback server?';

  @override
  String sync_confirm_rollback_server_content(Object revision) {
    return 'Rollback server to $revision and overwrite local data. This will create a new server revision.';
  }

  @override
  String get sync_confirm_rollback_server_confirm => 'Rollback';

  @override
  String get sync_rollback_done_title => 'Rollback complete';

  @override
  String sync_rollback_done_content(Object revision, Object newRevision) {
    return 'Rolled back to $revision and overwrote local data. New server revision: $newRevision';
  }

  @override
  String sync_rollback_done_partial_content(Object error) {
    return 'Server rolled back, but some tools failed to import:\\n$error';
  }

  @override
  String get sync_rollback_failed_title => 'Rollback failed';

  @override
  String get sync_confirm_rollback_local_title => 'Confirm local-only restore?';

  @override
  String sync_confirm_rollback_local_content(Object revision) {
    return 'Local data will be overwritten with server snapshot $revision, but the cloud current revision will not change.\\nNote: On next sync, local may be overwritten by cloud (use “Rollback server and overwrite local” instead).';
  }

  @override
  String get sync_confirm_rollback_local_confirm => 'Overwrite local';

  @override
  String get sync_overwrite_local_done_title => 'Local overwritten';

  @override
  String sync_overwrite_local_done_content(Object revision) {
    return 'Local overwritten to $revision';
  }

  @override
  String sync_overwrite_local_done_partial_content(Object error) {
    return 'Some tools failed to import:\\n$error';
  }

  @override
  String get sync_overwrite_local_failed_title => 'Overwrite failed';

  @override
  String get sync_diff_none => 'No diff details';

  @override
  String get sync_diff_format_error => 'Diff format error';

  @override
  String get sync_diff_no_substantive =>
      'No substantive changes (only ignored length changes)';

  @override
  String get sync_diff_unknown_item => '• Unknown diff item';

  @override
  String get tool_tag_manager_name => 'Tag Manager';

  @override
  String get tool_app_config_name => 'App Config';

  @override
  String get tag_category_location => 'Location';

  @override
  String get tag_category_item_type => 'Item type';

  @override
  String get tag_category_dish_type => 'Dish type';

  @override
  String get tag_category_ingredient => 'Ingredient';

  @override
  String get tag_category_sauce => 'Sauce';

  @override
  String get tag_category_affiliation => 'Affiliation';

  @override
  String get tag_category_flavor => 'Flavor';

  @override
  String get tag_category_meal_slot => 'Meal slot';

  @override
  String get sync_diff_label_added => 'Added';

  @override
  String get sync_diff_label_removed => 'Removed';

  @override
  String get sync_diff_label_modified => 'Modified';

  @override
  String get sync_diff_label_type_changed => 'Type changed';

  @override
  String get sync_diff_content_changed => 'Content changed';

  @override
  String get sync_diff_added_data => 'Data added';

  @override
  String get sync_diff_removed_data => 'Data removed';

  @override
  String sync_diff_detail_tag_added(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return 'Added $toolName $categoryName tag: 【$tagName】';
  }

  @override
  String sync_diff_detail_tag_removed(
    Object toolName,
    Object categoryName,
    Object tagName,
  ) {
    return 'Removed $toolName $categoryName tag: 【$tagName】';
  }

  @override
  String sync_diff_detail_named_added(Object name) {
    return 'Added: 【$name】';
  }

  @override
  String sync_diff_detail_named_removed(Object name) {
    return 'Removed: 【$name】';
  }

  @override
  String sync_diff_detail_titled_added(Object title) {
    return 'Added: 【$title】';
  }

  @override
  String sync_diff_detail_titled_removed(Object title) {
    return 'Removed: 【$title】';
  }

  @override
  String sync_diff_path_item(Object index) {
    return 'Item $index';
  }

  @override
  String get sync_auto_sync_success_toast => 'Auto sync succeeded';

  @override
  String sync_auto_sync_failed_toast(Object error) {
    return 'Auto sync failed: $error';
  }

  @override
  String get ai_settings_title => 'AI Settings';

  @override
  String get ai_settings_openai_section_title => 'OpenAI-Compatible Settings';

  @override
  String get ai_settings_base_url_label => 'Base URL';

  @override
  String get ai_settings_base_url_placeholder => 'https://api.openai.com/v1';

  @override
  String get ai_settings_api_key_label => 'API Key';

  @override
  String get ai_settings_api_key_placeholder => 'sk-...';

  @override
  String get ai_settings_model_label => 'Model';

  @override
  String get ai_settings_model_placeholder => 'gpt-4o-mini';

  @override
  String get ai_settings_temperature_label => 'Temperature';

  @override
  String get ai_settings_temperature_placeholder => '0.7';

  @override
  String get ai_settings_max_tokens_label => 'Max Tokens';

  @override
  String get ai_settings_max_tokens_placeholder => '1024';

  @override
  String get ai_settings_test_button => 'Test Connection';

  @override
  String get ai_settings_testing_button => 'Testing...';

  @override
  String get ai_settings_tips_section_title => 'Notes';

  @override
  String get ai_settings_tips_content =>
      '1. Base URL can be a domain (e.g. https://example.com) or include /v1.\\n2. Uses OpenAI-compatible endpoint: /v1/chat/completions.\\n3. API key is stored locally (SharedPreferences).';

  @override
  String get ai_settings_danger_section_title => 'Danger Zone';

  @override
  String get ai_settings_clear_button => 'Clear AI Settings';

  @override
  String get ai_settings_invalid_title => 'Tip';

  @override
  String get ai_settings_invalid_content =>
      'Check your settings: Base URL / API Key / Model must not be empty; temperature must be 0–2; Max Tokens must be > 0.';

  @override
  String get ai_settings_saved_title => 'Saved';

  @override
  String ai_settings_saved_content(Object model) {
    return 'Current model: $model';
  }

  @override
  String get ai_settings_test_invalid_content =>
      'Please enter a valid AI configuration before testing.';

  @override
  String get ai_settings_testing_loading_title => 'Testing';

  @override
  String get ai_settings_test_result_title => 'Test Result';

  @override
  String get ai_settings_test_failed_title => 'Test Failed';

  @override
  String get ai_settings_clear_confirm_title => 'Confirm clear?';

  @override
  String get ai_settings_clear_confirm_content =>
      'After clearing, AI features will be unavailable until you configure again.';

  @override
  String get ai_settings_clear_confirm_button => 'Clear';

  @override
  String get obj_store_settings_title => 'Object Storage';

  @override
  String get obj_store_settings_type_section_title => 'Storage Type';

  @override
  String get obj_store_settings_type_none_label => 'None';

  @override
  String get obj_store_settings_type_local_label => 'Local';

  @override
  String get obj_store_settings_type_qiniu_label => 'Qiniu';

  @override
  String get obj_store_settings_type_data_capsule_label => 'Data Capsule';
}
