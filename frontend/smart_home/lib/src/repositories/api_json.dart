// Validates API responses without modifying existing UI models.
Map<String, dynamic> jsonObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  return value;
}

List<Map<String, dynamic>> jsonObjects(Object? value) {
  if (value is! List) throw const FormatException('Expected a JSON array');
  return value.map(jsonObject).toList();
}

String jsonString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Expected a non-empty string for $key');
  }
  return value;
}

String? jsonOptionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Expected a string for $key');
  return value;
}

bool jsonBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Expected a boolean for $key');
  return value;
}

double jsonNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite) {
    throw FormatException('Expected a finite number for $key');
  }
  return value.toDouble();
}

num? jsonOptionalNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! num || !value.isFinite) {
    throw FormatException('Expected a finite number for $key');
  }
  return value;
}

int? jsonOptionalInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw FormatException('Expected an integer for $key');
  return value;
}

DateTime jsonDate(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(jsonString(json, key));
  if (value == null) throw FormatException('Expected a timestamp for $key');
  return value;
}
