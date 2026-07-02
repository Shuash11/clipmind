import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/domain/usecases/export_project_usecase.dart';
import 'package:clipmind/state/agent_providers.dart';

final exportUseCaseProvider = Provider<ExportProjectUseCase>((ref) {
  final ffmpegService = ref.watch(ffmpegServiceProvider);
  return ExportProjectUseCase(ffmpegService: ffmpegService);
});

final isExportingProvider = StateProvider<bool>((ref) => false);

final lastExportResultProvider =
    StateProvider<ExportResult?>((ref) => null);

final exportProgressProvider = StreamProvider<double>((ref) {
  final useCase = ref.watch(exportUseCaseProvider);
  return useCase.progressStream;
});
