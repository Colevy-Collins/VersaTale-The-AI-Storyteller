import 'package:flutter/foundation.dart';

import '../services/story_service.dart';
import '../services/lobby_rtdb_service.dart';
import '../utils/lobby_utils.dart';

/// A ChangeNotifier that owns all state & logic for “joining” a session.
class JoinController extends ChangeNotifier {
  final StoryService _storyService;
  final LobbyRtdbService _lobbyService;

  bool _isJoining = false;
  bool get isJoining => _isJoining;

  JoinController({
    required StoryService storyService,
    required LobbyRtdbService lobbyService,
  })  : _storyService = storyService,
        _lobbyService = lobbyService;

  /// Attempts to join. Returns (sessionId → playersMap).
  Future<MapEntry<String, Map<int, Map<String, dynamic>>>> join({
    required String joinCode,
    required String displayName,
  }) async {
    _setJoining(true);
    try {
      final result = await _storyService.joinMultiplayerSession(
        joinCode: joinCode,
        displayName: displayName,
      );

      final sessionId = result['sessionId'] as String;
      await _lobbyService.joinSession(
        sessionId: sessionId,
        displayName: displayName,
      );

      final rawPlayers = result['players'] ?? {};
      final normalized = LobbyUtils.normalizePlayers(rawPlayers);
      final playersMap = normalized.map<int, Map<String, dynamic>>(
            (key, value) => MapEntry(
          int.parse(key),
          Map<String, dynamic>.from(value),
        ),
      );

      return MapEntry(sessionId, playersMap);
    } finally {
      _setJoining(false);
    }
  }

  Future<bool> checkNewGame(String sessionId) =>
      _lobbyService.checkNewGame(sessionId: sessionId);

  void _setJoining(bool value) {
    _isJoining = value;
    notifyListeners();
  }
}
