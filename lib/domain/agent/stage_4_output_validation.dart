import 'dart:convert';
import 'package:clipmind/core/errors/failures.dart';
import 'operation_schema.dart';

class OutputValidator {
  static const List<String> validTypes = [
    'trim', 'cut', 'merge', 'change_speed', 'mute',
    'overlay_text', 'resize', 'rotate', 'extract_audio',
    'generate_thumbnail', 'change_format', 'adjust_brightness',
    'change_volume', 'overlay_watermark',
  ];

  static const Map<String, List<String>> requiredParams = {
    'trim': ['start', 'end'],
    'cut': ['remove_start', 'remove_end'],
    'merge': ['clip_ids'],
    'change_speed': ['factor'],
    'mute': [],
    'overlay_text': ['text'],
    'resize': ['width', 'height'],
    'rotate': ['degrees'],
    'extract_audio': [],
    'generate_thumbnail': [],
    'change_format': ['target_ext'],
    'adjust_brightness': ['value'],
    'change_volume': ['factor'],
    'overlay_watermark': ['image_path'],
  };

  static List<String> validateJson(String rawJson) {
    final errors = <String>[];

    Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(rawJson) as Map<String, dynamic>;
    } on FormatException catch (e) {
      errors.add('Invalid JSON: ${e.message}');
      return errors;
    } catch (e) {
      errors.add('Parse error: $e');
      return errors;
    }

    final ops = parsed['operations'] as List<dynamic>? ?? [];
    final summary = parsed['summary'] as String? ?? '';
    final clarification = parsed['clarification_needed'] as String?;

    if (ops.isEmpty && (clarification == null || clarification.trim().isEmpty)) {
      if (summary.isEmpty) {
        errors.add('Response has no operations and no clarification request');
        return errors;
      }
    }

    final seenTypes = <String, int>{};
    final seenIds = <String>{};

    for (int i = 0; i < ops.length; i++) {
      final op = ops[i] as Map<String, dynamic>;
      final type = op['type'] as String?;
      final id = op['id'] as String?;
      final target = op['target_clip_id'];

      if (id == null || id.trim().isEmpty) {
        errors.add('Operation $i: missing or empty id');
        continue;
      }
      if (seenIds.contains(id)) {
        errors.add('Operation "$id": duplicate operation id');
      }
      seenIds.add(id);

      if (type == null || !validTypes.contains(type)) {
        errors.add('Operation "$id": invalid type "$type"');
        continue;
      }

      if (target == null) {
        errors.add('Operation "$id": missing target_clip_id');
      }

      final params = op['params'] as Map<String, dynamic>? ?? {};
      final required = requiredParams[type] ?? [];
      for (final param in required) {
        if (!params.containsKey(param) || params[param] == null) {
          errors.add('Operation "$id": missing required param "$param" for $type');
        } else {
          final value = params[param];
          if (value is String && value.trim().isEmpty) {
            errors.add('Operation "$id": param "$param" value is empty');
          } else if (value is num && num.parse(value.toString()) <= 0) {
            errors.add('Operation "$id": param "$param" must be a positive number, got "$value"');
          }
        }
      }

      seenTypes[type] = (seenTypes[type] ?? 0) + 1;

      if (type == 'trim') {
        final start = params['start'] as String?;
        final end = params['end'] as String?;
        if (start != null && end != null) {
          final startMs = _parseTimecodeMs(start);
          final endMs = _parseTimecodeMs(end);
          if (startMs != null && endMs != null && endMs <= startMs) {
            errors.add('Operation "$id": trim end ($end) must be after start ($start)');
          }
        }
      }
    }

    for (final entry in seenTypes.entries) {
      final conflictOps = ['change_format', 'mute'];
      if (conflictOps.contains(entry.key) && entry.value > 1) {
        errors.add('Conflict: ${entry.key} appears ${entry.value} times in same batch');
      }
    }

    return errors;
  }

  static (EditOperationSet?, Stage4Failure?, ClarificationNeeded?) validate(
    String rawJson,
  ) {
    final errors = validateJson(rawJson);

    if (errors.isNotEmpty) {
      return (null, Stage4Failure(errors.join('; ')), null);
    }

    final parsed = jsonDecode(rawJson) as Map<String, dynamic>;
    final ops = parsed['operations'] as List<dynamic>? ?? [];
    final summary = parsed['summary'] as String? ?? '';
    final clarification = parsed['clarification_needed'] as String?;

    if (clarification != null && clarification.trim().isNotEmpty) {
      return (
        null,
        null,
        ClarificationNeeded(
          question: clarification,
          options: [],
        ),
      );
    }

    return (
      EditOperationSet(
        operations: ops
            .map((o) => EditOperationRequest.fromJson(o as Map<String, dynamic>))
            .toList(),
        summary: summary,
        clarificationNeeded: null,
      ),
      null,
      null,
    );
  }

  static String buildRetryPrompt(String originalCommand, List<String> errors) {
    return '''
The previous response had validation errors. Please fix and retry.

Original command: $originalCommand

Validation errors:
${errors.map((e) => '- $e').join('\n')}

Return ONLY a corrected JSON object following the exact schema. Do NOT explain.
''';
  }

  static int? _parseTimecodeMs(String tc) {
    final parts = tc.split(RegExp(r'[:.]'));
    if (parts.length < 2) return null;
    try {
      final h = parts.length >= 4 ? int.parse(parts[0]) : 0;
      final m = int.parse(parts[parts.length >= 4 ? 1 : 0]);
      final s = int.parse(parts[parts.length >= 4 ? 2 : 1]);
      final ms = parts.length >= 4
          ? int.parse(parts[3].padRight(3, '0').substring(0, 3))
          : parts.length >= 3
              ? int.parse(parts[2].padRight(3, '0').substring(0, 3))
              : 0;
      return ((h * 3600 + m * 60 + s) * 1000 + ms);
    } catch (_) {
      return null;
    }
  }
}
