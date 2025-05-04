import 'dart:math';

class DimensionUtils {
  /// Recursively flattens an arbitrarily nested map to  `path → [leaf values]`.
  static Map<String, List<String>> flattenLeaves(dynamic node,
      [String prefix = '']) {
    final out = <String, List<String>>{};

    void recurse(dynamic n, String path) {
      if (n is Map<String, dynamic>) {
        n.forEach((k, v) => recurse(v, path.isEmpty ? k : '$path.$k'));
      } else if (n is Iterable) {
        out[path] = n.map((e) => e.toString()).toList();
      } else {
        out[path] = [n.toString()];
      }
    }

    recurse(node, prefix);
    return out;
  }

  /// Returns a **leaf‑only** map with either the user’s pick or a sensible
  /// default/random value.
  static Map<String, String> randomDefaults({
    required Map<String, dynamic> dimensionGroups,
    required Map<String, String?> userChoices,
  }) {
    final rand     = Random();
    final defaults = <String, String>{};

    final leaves = flattenLeaves(dimensionGroups);

    leaves.forEach((path, options) {
      final key = path.split('.').last;
      if (key == 'Minimum Number of Options') {
        defaults[key] = userChoices[key] ?? '2';
      } else if (key == 'Story Length') {
        defaults[key] = userChoices[key] ?? 'Short';
      } else {
        defaults[key] = userChoices[key] ??
            options[rand.nextInt(options.length)];
      }
    });

    return defaults;
  }
}
