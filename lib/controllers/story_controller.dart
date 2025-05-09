import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

import '../constants/story_tokens.dart';
import '../models/story_phase.dart';
import '../services/auth_service.dart';
import '../services/lobby_rtdb_service.dart';
import '../services/story_service.dart';
import '../utils/lobby_utils.dart';

class StoryController with ChangeNotifier {
  // ───────────────────────── constructor ────────────────────────────────
  StoryController({
    // immutable inputs from widget
    required this.initialLeg,
    required this.initialOptions,
    required this.storyTitle,
    this.sessionId,
    this.joinCode,
    this.onKicked,
    // dependency injection
    AuthService?      authService,
    StoryService?     storyService,
    LobbyRtdbService? lobbyService,
    // host-widget callbacks
    void Function(String msg)? onError,
    void Function(String msg)? onInfo,
    // seed counters so badge is correct on first frame
    this.initialInputTokens      = 0,
    this.initialOutputTokens     = 0,
    this.initialEstimatedCostUsd = 0.0,
  })  : _authSvc  = authService  ?? AuthService(),
        _storySvc = storyService ?? StoryService(),
        _lobbySvc = lobbyService ?? LobbyRtdbService(),
        _onError  = onError,
        _onInfo   = onInfo,
        _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '' {
    // seed narrative
    _text    = initialLeg;
    _options = List.of(initialOptions);
    _title   = storyTitle;
    _phase   = StoryPhase.story;

    // seed usage counters
    _inputTokens      = initialInputTokens;
    _outputTokens     = initialOutputTokens;
    _estimatedCostUsd = initialEstimatedCostUsd;

    // multiplayer listener
    if (isMultiplayer) {
      _lobbySub =
          _lobbySvc.lobbyStream(sessionId!).listen(_onLobbyUpdate);
    }
  }

  // immutable constructor fields
  final String initialLeg;
  final List<String> initialOptions;
  final String storyTitle;
  final String? sessionId;
  final String? joinCode;
  final VoidCallback? onKicked;
  final int    initialInputTokens;
  final int    initialOutputTokens;
  final double initialEstimatedCostUsd;

  // injected services
  final AuthService      _authSvc;
  final StoryService     _storySvc;
  final LobbyRtdbService _lobbySvc;

  // UI callbacks
  final void Function(String msg)? _onError;
  final void Function(String msg)? _onInfo;
  void _error(String m) => _onError?.call(m);
  void _info (String m) => _onInfo ?.call(m);

  // private state
  final String _currentUid;
  late String _text;
  late List<String> _options;
  late String _title;
  late StoryPhase _phase;

  // usage counters (monotonic)
  int    _inputTokens      = 0;
  int    _outputTokens     = 0;
  double _estimatedCostUsd = 0.0;

  bool _busy    = false;
  bool _loading = false;

  int _inLobbyCount = 0;
  Map<String, dynamic> _players = {};

  StreamSubscription<DatabaseEvent>? _lobbySub;

  // getters for widgets
  String       get text     => _text;
  List<String> get options  => List.unmodifiable(_options);
  String       get title    => _title;
  StoryPhase   get phase    => _phase;
  bool         get busy     => _busy;
  bool         get loading  => _loading;
  int          get inLobby  => _inLobbyCount;

  int    get inputTokens      => _inputTokens;
  int    get outputTokens     => _outputTokens;
  double get estimatedCostUsd => _estimatedCostUsd;

  bool get isMultiplayer => sessionId != null;
  bool get isHost {
    final slot1 = _players['1'];
    return slot1 is Map && slot1['userId'] == _currentUid;
  }

  // lifecycle
  void disposeController() {
    _lobbySub?.cancel();
  }

  /* ──────────────────── NEW: monotonic counter helper ─────────────────── */
  void _mergeCounters(Map<String, dynamic> src) {
    final inTok = src['inputTokens'] as int?;
    if (inTok != null && inTok > _inputTokens) _inputTokens = inTok;

    final outTok = src['outputTokens'] as int?;
    if (outTok != null && outTok > _outputTokens) _outputTokens = outTok;

    final cost = src['estimatedCostUsd'] as num?;
    if (cost != null && cost > _estimatedCostUsd) {
      _estimatedCostUsd = cost.toDouble();
    }
  }

  /* ───────────────────────── public API ─────────────────────────────── */

  Future<void> chooseNext(String decision) async {
    if (decision.trim() == 'The story ends!') {
      _info?.call('The story has ended — no further actions available.');
      return;
    }
    if (_busy) return;
    _setBusy(true);

    try {
      if (isMultiplayer) {
        if (_phase == StoryPhase.story) {
          await _lobbySvc.updatePhase(
            sessionId: sessionId!,
            phase    : StoryPhase.vote.asString,
            isNewGame: false,
          );
          await _submitVote(decision);
        } else if (_phase == StoryPhase.vote) {
          await _submitVote(decision);
        }
      } else {
        await _advanceSolo(decision);
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> backOneLeg() async {
    if (isMultiplayer) {
      await chooseNext(kPreviousLegToken);
    } else {
      await _soloPreviousLeg();
    }
  }

  Future<void> resolveVotesManually() => _resolveAndAdvance();

  Future<void> hostBringEveryoneBack() async {
    if (!isHost || !isMultiplayer) return;
    _setBusy(true);
    try {
      await _lobbySvc.advanceToStoryPhase(
        sessionId: sessionId!,
        storyPayload: {
          'initialLeg'      : _text,
          'options'         : List<String>.from(_options),
          'storyTitle'      : _title,
          'inputTokens'     : _inputTokens,
          'outputTokens'    : _outputTokens,
          'estimatedCostUsd': _estimatedCostUsd,
        },
      );
    } catch (e) {
      _error('Error bringing players back: $e');
    } finally {
      _setBusy(false);
    }
  }

  /* ────────────────────── RTDB listener ────────────────────────────── */

  void _onLobbyUpdate(DatabaseEvent event) {
    final root = (event.snapshot.value as Map?)?.cast<dynamic, dynamic>() ?? {};

    // lobby count
    _inLobbyCount = root['inLobbyCount'] as int? ?? _inLobbyCount;

    // players & phase
    _players = LobbyUtils.normalizePlayers(root['players']);
    final newPhase = StoryPhaseParsing.fromString(root['phase']?.toString() ?? '');
    final phaseChanged = newPhase != _phase;
    if (phaseChanged) _phase = newPhase;

    // auto-resolve votes if host
    if (_phase == StoryPhase.vote && isHost && !_busy) {
      final votes = LobbyUtils.normalizePlayers(root['storyVotes']).length;
      if (_players.isNotEmpty && votes >= _players.length) {
        _resolveAndAdvance();
      }
    }

    // incoming story payload
    if (_phase == StoryPhase.story && root['storyPayload'] != null) {
      final p = (root['storyPayload'] as Map).cast<String, dynamic>();
      _text    = p['initialLeg'] as String;
      _options = List<String>.from(p['options'] as List);
      _title   = p['storyTitle'] as String;
      _mergeCounters(p);                // ← keep counters monotonic
    }

    // kicked?
    final stillHere = _players.values.any((p) => p['userId'] == _currentUid);
    if (!stillHere) {
      _lobbySub?.cancel();
      onKicked?.call();
    }

    if (phaseChanged) notifyListeners();
    notifyListeners();
  }

  /* ────────────────────── vote helpers ─────────────────────────────── */

  Future<void> _submitVote(String choice) async {
    try {
      await _lobbySvc.submitStoryVote(sessionId: sessionId!, vote: choice);
      await _maybeAutoResolve();
    } catch (e) {
      _error('$e');
      await _rollbackToStoryPhase();
    }
  }

  Future<void> _maybeAutoResolve() async {
    if (!isHost || sessionId == null) return;
    final snap = await FirebaseDatabase.instance.ref('lobbies/$sessionId').get();
    final raw = snap.value;
    if (raw is! Map) return;

    final players = LobbyUtils.normalizePlayers(raw['players']);
    final votes   = LobbyUtils.normalizePlayers(raw['storyVotes']);
    final phaseEnum = StoryPhaseParsing.fromString(raw['phase']?.toString() ?? '');

    if (phaseEnum == StoryPhase.vote &&
        players.isNotEmpty &&
        votes.length >= players.length) {
      await _resolveAndAdvance();
    }
  }

  /* ────────────────────── solo helpers ─────────────────────────────── */

  Future<void> _advanceSolo(String decision) async {
    try {
      final r = (decision == kPreviousLegToken)
          ? await _storySvc.getPreviousLeg()
          : await _storySvc.getNextLeg(decision: decision);

      _text    = r['storyLeg'] ?? 'No leg returned.';
      _options = List<String>.from(r['options'] ?? []);
      if (r.containsKey('storyTitle')) _title = r['storyTitle'];

      _mergeCounters(r);               // ← monotonic update
      notifyListeners();
    } catch (e) {
      _error('$e');
    }
  }

  Future<void> _soloPreviousLeg() async {
    try {
      final r = await _storySvc.getPreviousLeg();

      _text    = r['storyLeg'] ?? 'No leg returned.';
      _options = List<String>.from(r['options'] ?? []);
      if (r.containsKey('storyTitle')) _title = r['storyTitle'];

      _mergeCounters(r);               // ← monotonic update
      notifyListeners();
    } catch (e) {
      _error('$e');
    }
  }

  /* ────────────────────── vote resolution ─────────────────────────── */

  Future<void> _resolveAndAdvance() async {
    _setBusy(true);
    try {
      await _lobbySvc.updatePhase(
        sessionId: sessionId!,
        phase: StoryPhase.results.asString,
        isNewGame: false,
      );

      final winner = await _lobbySvc.resolveStoryVotes(sessionId!);

      final nextPayload = (winner == kPreviousLegToken)
          ? await _storySvc.getPreviousLeg()
          : await _storySvc.getNextLeg(decision: winner);

      _mergeCounters(nextPayload);      // ← monotonic update

      await _lobbySvc.advanceToStoryPhase(
        sessionId: sessionId!,
        storyPayload: {
          'initialLeg'      : nextPayload['storyLeg'],
          'options'         : List<String>.from(nextPayload['options'] ?? []),
          'storyTitle'      : nextPayload['storyTitle'],
          'inputTokens'     : _inputTokens,
          'outputTokens'    : _outputTokens,
          'estimatedCostUsd': _estimatedCostUsd,
        },
      );
    } catch (e) {
      _error('Error resolving votes: $e');
      await _rollbackToStoryPhase();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _rollbackToStoryPhase() async {
    _phase = StoryPhase.story;
    notifyListeners();
    if (isMultiplayer) {
      try {
        await _lobbySvc.updatePhase(
          sessionId: sessionId!,
          phase    : StoryPhase.story.asString,
          isNewGame: false,
        );
      } catch (_) {}
    }
  }

  /* ────────────────────── misc helpers ─────────────────────────────── */
  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }
}
