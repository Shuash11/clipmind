import 'package:uuid/uuid.dart';

import '../../domain/ids/id_generator.dart';

final class UuidIdGenerator implements IdGenerator {
  UuidIdGenerator([Uuid? uuid]) : _uuid = uuid ?? const Uuid();
  final Uuid _uuid;

  @override
  String next() => _uuid.v4();
}
