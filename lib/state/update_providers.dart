import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:clipmind/data/services/updates/github_release_checker.dart';
import 'package:clipmind/data/services/updates/release_info.dart';

enum UpdateStatus { idle, checking, available, upToDate, error }

class UpdateState {
  final UpdateStatus status;
  final ReleaseInfo? release;
  final String? errorMessage;

  const UpdateState({this.status = UpdateStatus.idle, this.release, this.errorMessage});

  UpdateState copyWith({UpdateStatus? status, ReleaseInfo? release, String? errorMessage}) {
    return UpdateState(
      status: status ?? this.status,
      release: release ?? this.release,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  final GithubReleaseChecker _checker;

  UpdateNotifier(this._checker) : super(const UpdateState());

  Future<void> checkForUpdate({String currentVersion = '1.0.0'}) async {
    state = state.copyWith(status: UpdateStatus.checking);
    try {
      final release = await _checker.checkForUpdate();
      if (release == null) {
        state = state.copyWith(status: UpdateStatus.error, errorMessage: 'Could not reach update server');
        return;
      }
      if (_checker.isNewer(release, currentVersion)) {
        state = state.copyWith(status: UpdateStatus.available, release: release);
      } else {
        state = state.copyWith(status: UpdateStatus.upToDate);
      }
    } catch (e) {
      state = state.copyWith(status: UpdateStatus.error, errorMessage: e.toString());
    }
  }

  void dismiss() => state = const UpdateState();
}

final githubReleaseCheckerProvider = Provider<GithubReleaseChecker>((ref) {
  return GithubReleaseChecker();
});

final updateNotifierProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  final checker = ref.watch(githubReleaseCheckerProvider);
  return UpdateNotifier(checker);
});
