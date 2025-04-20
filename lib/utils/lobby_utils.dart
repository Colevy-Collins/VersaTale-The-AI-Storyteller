// lib/utils/lobby_utils.dart
class LobbyUtils {
  /// Takes either a Map or List from RTDB and returns a clean Map<String,dynamic>.
  static Map<String, dynamic> normalizePlayers(dynamic raw) {
    final out = <String, dynamic>{};
    if (raw is Map) {
      raw.forEach((k, v) => out[k.toString()] = v);
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final e = raw[i];
        if (e is Map) out['$i'] = e;
      }
    }
    return out;
  }
}
