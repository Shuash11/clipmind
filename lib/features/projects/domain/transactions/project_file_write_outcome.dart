abstract base class ProjectSaveWarning {
  const ProjectSaveWarning(this.code, this.message);
  final String code;
  final String message;
}

final class ProjectFileWarning extends ProjectSaveWarning {
  const ProjectFileWarning(super.code, super.message);
}

final class ProjectIndexWarning extends ProjectSaveWarning {
  const ProjectIndexWarning(super.code, super.message);
}

final class ProjectFileWriteOutcome {
  const ProjectFileWriteOutcome({this.warning});
  final ProjectFileWarning? warning;
}
