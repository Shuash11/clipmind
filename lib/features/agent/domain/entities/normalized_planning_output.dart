import 'tool_call.dart';
import 'validation_finding.dart';

/// The closed result of decoding provider output.  Invalid output never keeps a
/// partially decoded operation list.
final class NormalizedPlanningOutput {
  NormalizedPlanningOutput({
    required this.summary,
    Iterable<ToolCall> calls = const <ToolCall>[],
    Iterable<ValidationFinding> findings = const <ValidationFinding>[],
  }) : calls = List<ToolCall>.unmodifiable(calls),
       findings = List<ValidationFinding>.unmodifiable(findings);

  final String summary;
  final List<ToolCall> calls;
  final List<ValidationFinding> findings;

  List<ToolCall> get toolCalls => calls;
  List<ValidationFinding> get validationFindings => findings;
  bool get isValid => findings.isEmpty && calls.isNotEmpty;

  factory NormalizedPlanningOutput.invalid(ValidationFinding finding) =>
      NormalizedPlanningOutput(
        summary: 'The model response could not be used.',
        findings: [finding],
      );
}
