import 'package:path/path.dart' as p;

bool isPathWithinAnyDir({
  required String filePath,
  required List<String> dirPaths,
}) {
  final file = p.normalize(filePath);
  for (final dir in dirPaths) {
    final d = p.normalize(dir);
    if (d.trim().isEmpty) continue;
    if (p.isWithin(d, file) || p.equals(d, p.dirname(file))) {
      return true;
    }
  }
  return false;
}
