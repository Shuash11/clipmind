class EvalResult {
  final String id;
  final bool passed;
  final String category;
  final String difficulty;
  final String? error;
  final int? stage;

  EvalResult({
    required this.id,
    required this.passed,
    required this.category,
    required this.difficulty,
    this.error,
    this.stage,
  });
}

class AccuracyReport {
  final List<EvalResult> results;

  AccuracyReport(this.results);

  double get overallAccuracy {
    if (results.isEmpty) return 0;
    final passed = results.where((r) => r.passed).length;
    return (passed / results.length) * 100;
  }

  Map<String, double> perCategoryAccuracy() {
    final byCategory = <String, List<EvalResult>>{};
    for (final r in results) {
      byCategory.putIfAbsent(r.category, () => []).add(r);
    }
    return byCategory.map((cat, list) {
      final passed = list.where((r) => r.passed).length;
      return MapEntry(cat, (passed / list.length) * 100);
    });
  }

  Map<String, double> perDifficultyAccuracy() {
    final byDiff = <String, List<EvalResult>>{};
    for (final r in results) {
      byDiff.putIfAbsent(r.difficulty, () => []).add(r);
    }
    return byDiff.map((diff, list) {
      final passed = list.where((r) => r.passed).length;
      return MapEntry(diff, (passed / list.length) * 100);
    });
  }

  List<EvalResult> get failures => results.where((r) => !r.passed).toList();

  String format() {
    final buf = StringBuffer();
    buf.writeln('========================================');
    buf.writeln('  NLP ACCURACY EVALUATION REPORT');
    buf.writeln('========================================');
    buf.writeln();
    buf.writeln('Overall Accuracy: ${overallAccuracy.toStringAsFixed(1)}%');
    buf.writeln('Total Commands: ${results.length}');
    buf.writeln('Passed: ${results.where((r) => r.passed).length}');
    buf.writeln('Failed: ${results.where((r) => !r.passed).length}');
    buf.writeln();
    buf.writeln('--- Per Category ---');
    final catAcc = perCategoryAccuracy();
    for (final entry in catAcc.entries) {
      buf.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(1)}%');
    }
    buf.writeln();
    buf.writeln('--- Per Difficulty ---');
    final diffAcc = perDifficultyAccuracy();
    for (final entry in diffAcc.entries) {
      buf.writeln('  ${entry.key}: ${entry.value.toStringAsFixed(1)}%');
    }
    if (failures.isNotEmpty) {
      buf.writeln();
      buf.writeln('--- Failed Commands ---');
      for (final f in failures) {
        final stageInfo = f.stage != null ? ' (Stage ${f.stage})' : '';
        buf.writeln('  [${f.category}] ${f.id}$stageInfo: ${f.error ?? 'mismatch'}');
      }
    }
    return buf.toString();
  }
}
