/// Lenient readers for settings JSON: a missing or malformed value falls
/// back to its default instead of failing the whole file.
library;

Map<String, dynamic> jsonObject(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

int jsonInt(Object? value, int fallback, {int min = 0, int? max}) {
  if (value is! int || value < min || (max != null && value > max)) {
    return fallback;
  }
  return value;
}

bool jsonBool(Object? value, bool fallback) => value is bool ? value : fallback;

T jsonEnum<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;
