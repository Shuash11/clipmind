class TimecodeUtils {
  TimecodeUtils._();

  static final RegExp _timecodePattern = RegExp(
    r'^(?:(\d+):)?(\d+):(\d+)(?:\.(\d{1,3}))?$',
  );

  static final RegExp _secondsPattern = RegExp(
    r'^(\d+(?:\.\d+)?)\s*s(?:econds?)?$',
  );

  static final RegExp _minutesPattern = RegExp(
    r'^(\d+(?:\.\d+)?)\s*m(?:in(?:utes?)?)?$',
  );

  static int? parseToMilliseconds(String input) {
    final trimmed = input.trim().toLowerCase();

    final secondsMatch = _secondsPattern.firstMatch(trimmed);
    if (secondsMatch != null) {
      final seconds = double.parse(secondsMatch.group(1)!);
      return (seconds * 1000).round();
    }

    final minutesMatch = _minutesPattern.firstMatch(trimmed);
    if (minutesMatch != null) {
      final minutes = double.parse(minutesMatch.group(1)!);
      return (minutes * 60 * 1000).round();
    }

    final tcMatch = _timecodePattern.firstMatch(trimmed);
    if (tcMatch != null) {
      final hours = int.parse(tcMatch.group(1) ?? '0');
      final minutes = int.parse(tcMatch.group(2)!);
      final seconds = int.parse(tcMatch.group(3)!);
      final millisStr = tcMatch.group(4) ?? '0';
      final millis = int.parse(millisStr.padRight(3, '0').substring(0, 3));
      return ((hours * 3600 + minutes * 60 + seconds) * 1000 + millis);
    }

    return null;
  }

  static String formatMs(int ms) {
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final millis = ms % 1000;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}.'
          '${millis.toString().padLeft(3, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  static String formatShort(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
}
