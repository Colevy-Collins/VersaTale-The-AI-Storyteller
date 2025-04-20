// lib/controllers/lobby_host_controller.dart
// -----------------------------------------------------------------------------
// ChangeNotifier that owns all host‑side lobby logic.
// Fix: treats an empty or missing userId as "kicked" so the local client
// still routes home even if the RTDB node wasn't fully removed.
// -----------------------------------------------------------------------------

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../services/lobby_rtdb_service.dart';
import '../models/player.dart';
import '../utils/lobby_utils.dart';

class LobbyHostController extends ChangeNotifier {
  // ---------------------------------------------------------------------------
  // Dependencies & ctor‑injected state
  // ---------------------------------------------------------------------------
  final LobbyRtdbService _svc;
  final String sessionId;
  final String currentUserId;
  final bool fromSoloStory;
  final bool fromGroupStory;

  // ---------------------------------------------------------------------------
  // Observable state consumed by the UI
  // ---------------------------------------------------------------------------
  List<Player> players = [];
  bool isResolving            = false;
  bool shouldNavigateToResults = false;
  bool shouldNavigateToStory   = false;
  bool isKicked               = false;
  Map<String,String>?   resolvedResults;
  Map<String,dynamic>?  storyPayload;
  String? lastError;

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------
  StreamSubscription<DatabaseEvent>? _sub;
  String? _lastPhase;
  bool    _navigated = false;

  LobbyHostController({
    required this.sessionId,
    required this.currentUserId,
    required Map<int,Map<String,dynamic>> initialPlayers,
    this.fromSoloStory  = false,
    this.fromGroupStory = false,
    LobbyRtdbService? service,
  }) : _svc = service ?? LobbyRtdbService() {
    // seed players so first frame renders something
    players = initialPlayers.entries
        .map((e)=>Player.fromJson(e.key,e.value))
        .toList()
      ..sort((a,b)=>a.slot.compareTo(b.slot));

    _init();
  }

  // Convenience getter
  bool get isHost => players.isNotEmpty && players.first.userId == currentUserId;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------
  void _init() {
    _svc.incrementInLobbyCount(sessionId).catchError(_handleError);
    _sub = _svc.lobbyStream(sessionId).listen(_onLobbyEvent, onError: _handleError);
  }

  @override
  void dispose() {
    _svc.decrementInLobbyCount(sessionId).catchError(_handleError);
    _sub?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI actions
  // ---------------------------------------------------------------------------
  Future<void> kickPlayer(int slot) async {
    try {
      await _svc.kickPlayer(sessionId: sessionId, slot: slot);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> changeMyName(String newName) async {
    try {
      await _svc.updateMyName(sessionId, newName);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<void> startGroupStory() async {
    if (!isHost || isResolving) return;
    _setResolving(true);
    try {
      await _svc.resolveVotes(sessionId);
    } catch (e) {
      _handleError(e);
    } finally {
      _setResolving(false);
    }
  }

  Future<void> startSoloStory() async {
    if (!isHost || isResolving) return;
    _setResolving(true);
    try {
      await FirebaseDatabase.instance
          .ref('lobbies/$sessionId')
          .update({'phase':'story'});
    } catch (e) {
      _handleError(e);
    } finally {
      _setResolving(false);
    }
  }

  /// After vote‑results path (fromGroupStory == true)
  Future<void> goToStoryAfterResults() async {
    if (_navigated || isResolving) return;
    _setResolving(true);
    try {
      storyPayload = await _svc.fetchStoryPayloadIfInStoryPhase(sessionId: sessionId)
          ?? await _svc.fetchStoryPayload(sessionId: sessionId);
      if (storyPayload != null) {
        shouldNavigateToStory = true;
        _navigated = true;
      }
    } catch (e) {
      _handleError(e);
    } finally {
      _setResolving(false);
    }
  }

  void navigationHandled() {
    shouldNavigateToResults = false;
    shouldNavigateToStory   = false;
    notifyListeners();
  }

  void clearError() { lastError = null; notifyListeners(); }

  // ---------------------------------------------------------------------------
  // RTDB listener
  // ---------------------------------------------------------------------------
  void _onLobbyEvent(DatabaseEvent event) {
    final root = event.snapshot.value as Map<dynamic,dynamic>? ?? {};

    // --- players snapshot → typed list
    final flat = LobbyUtils.normalizePlayers(root['players']);
    final newPlayers = flat.entries
        .map((e)=>Player.fromJson(int.parse(e.key), Map<String,dynamic>.from(e.value)))
        .toList()
      ..sort((a,b)=>a.slot.compareTo(b.slot));

    // --- detect kick (treat empty userId as kicked)
    final stillHere = newPlayers.any((p)=> p.userId.isNotEmpty && p.userId == currentUserId);
    if (!stillHere) {
      isKicked = true;
      notifyListeners();
      _sub?.cancel();
      return;
    }

    players = newPlayers;

    // --- phase transitions
    final newPhase = (root['phase'] as String?) ?? 'lobby';
    _lastPhase ??= newPhase;

    if (!_navigated && newPhase != _lastPhase) {
      if (newPhase == 'voteResults' && root['resolvedDimensions'] != null) {
        resolvedResults = Map<String,String>.from(root['resolvedDimensions'] as Map);
        shouldNavigateToResults = true;
        _navigated = true;
      } else if (newPhase == 'story' && root['storyPayload'] != null) {
        storyPayload = Map<String,dynamic>.from(root['storyPayload']);
        shouldNavigateToStory = true;
        _navigated = true;
      }
    }

    _lastPhase = newPhase;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  void _setResolving(bool v) { isResolving = v; notifyListeners(); }

  void _handleError(Object e) { lastError = e.toString(); notifyListeners(); }
}
