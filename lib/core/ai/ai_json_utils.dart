import 'dart:convert';

class AiJsonUtils {
  static Map<String, Object?>? decodeFirstObject(String text) {
    final trimmed = text.trim();
    final decoded = _tryDecodeObject(trimmed);
    if (decoded != null) return decoded;

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final extracted = trimmed.substring(start, end + 1);
    return _tryDecodeObject(extracted);
  }

  static Map<String, Object?>? asMap(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    return null;
  }

  static List<Object?>? asList(Object? value) {
    if (value is List) {
      return value.cast<Object?>();
    }
    return null;
  }

  static String? asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static double? asDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  static DateTime? parseDateOnly(String? value) {
    final parsed = parseDateTime(value);
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static Map<String, Object?>? _tryDecodeObject(String text) {
    try {
      final value = jsonDecode(text);
      if (value is Map) {
        return value.cast<String, Object?>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
