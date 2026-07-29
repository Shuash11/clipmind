bool listEquals<T>(List<T> left, List<T> right) {
  if (identical(left, right)) return true;
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

bool setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

int listHash<T>(List<T> values) => Object.hashAll(values);

int setHash<T>(Set<T> values) => Object.hashAll(
  values.toList()..sort((a, b) => a.toString().compareTo(b.toString())),
);
