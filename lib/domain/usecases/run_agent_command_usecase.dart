import 'package:clipmind/domain/agent/nl2vec_pipeline.dart';
import 'package:clipmind/domain/agent/operation_schema.dart';

class RunAgentCommandUseCase {
  final Nl2VecPipeline _pipeline;

  RunAgentCommandUseCase(this._pipeline);

  Future<String> execute(String command, ProjectSnapshot project) {
    return _pipeline.submitCommand(command, project);
  }
}
