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
  // ─────────────────────────── constructor ────────────────────────────────
  StoryController({
    // immutable inputs from the widget
    required this.initialLeg,
    required this.initialOptions,
    required this.storyTitle,
    this.sessionId,
    this.joinCode,
    // DI (handy for tests)
    AuthService? authService,
    StoryService? storyService,
    LobbyRtdbService? lobbyService,
    // callbacks for UI messages
    void Function(String msg)? onError,
    void Function(String msg)? onInfo,
  })  : _authSvc  = authService  ?? AuthService(),
        _storySvc = storyService ?? StoryService(),
        _lobbySvc = lobbyService ?? LobbyRtdbService(),
        _onError  = onError,
        _onInfo   = onInfo,
        _currentUid = FirebaseAuth.instance.currentUser?.uid ?? '' {
    // seed local state
    _text    = initialLeg;
    _options = List.of(initialOptions);
    _title   = storyTitle;
    _phase   = StoryPhase.story;

    // start RTDB listener for multiplayer
    if (isMultiplayer) {
      _lobbySub = _lobbySvc
          .lobbyStream(sessionId!)
          .listen(_onLobbyUpdate);
    }
  }

  // ───────────────────────── immutable, public fields ─────────────────────
  final String  initialLeg;
  final List<String> initialOptions;
  final String  storyTitle;
  final String? sessionId;
  final String? joinCode;

  // ───────────────────────── injected services ────────────────────────────
  final AuthService      _authSvc;
  final StoryService     _storySvc;
  final LobbyRtdbService _lobbySvc;

  // ───────────────────────── callbacks to UI ──────────────────────────────
  final void Function(String msg)? _onError;
  final void Function(String msg)? _onInfo;
  void _error(String m) => _onError?.call(m);
  void _info (String m) => _onInfo ?.call(m);

  // ───────────────────────── private state ────────────────────────────────
  final String _currentUid;
  late String _text;
  late List<String> _options;
  late String _title;
  late StoryPhase _phase;

  bool _busy    = false;
  bool _loading = false;

  int _inLobbyCount = 0;
  Map<String, dynamic> _players = {};

  StreamSubscription<DatabaseEvent>? _lobbySub;

  // ───────────────────────── public getters (widget listens) ──────────────
  String        get text     => _text;
  List<String>  get options  => List.unmodifiable(_options);
  String        get title    => _title;
  StoryPhase    get phase    => _phase;
  bool          get busy     => _busy;
  bool          get loading  => _loading;
  int           get inLobby  => _inLobbyCount;

  bool get isMultiplayer => sessionId != null;
  bool get isHost {
    final slot1 = _players['1'];
    return slot1 is Map && slot1['userId'] == _currentUid;
  }

  // ───────────────────────── lifecycle ────────────────────────────────────
  void disposeController() {
    _lobbySub?.cancel();
  }

  // ───────────────────────── public API called by widget ──────────────────

  Future<void> chooseNext(String decision) async {
    if (_busy) return;
    _setBusy(true);

    try {
      if (isMultiplayer) {
        if (_phase == StoryPhase.story) {
          await _lobbySvc.updatePhase(
              sessionId: sessionId!, phase: StoryPhase.vote.asString);
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
      await _lobbySvc.updatePhase(
        sessionId: sessionId!,
        phase: StoryPhase.story.asString,
      );
    } catch (e) {
      _error('$e');
    } finally {
      _setBusy(false);
    }
  }

  // ───────────────────────── RTDB listener ────────────────────────────────
  void _onLobbyUpdate(DatabaseEvent event) {
    final root = (event.snapshot.value as Map?)?.cast<dynamic, dynamic>() ?? {};

    // 1. lobby count
    final newCount = root['inLobbyCount'] as int? ?? 0;
    if (newCount != _inLobbyCount) {
      _inLobbyCount = newCount;
      notifyListeners();
    }

    // 2. players & phase
    _players = LobbyUtils.normalizePlayers(root['players']);
    final newPhase =
    StoryPhaseParsing.fromString(root['phase']?.toString() ?? '');
    final phaseChanged = newPhase != _phase;
    if (phaseChanged) {
      _phase = newPhase;
      notifyListeners();
    }

    // 3. auto‑resolve if host
    if (_phase == StoryPhase.vote && isHost && !_busy) {
      final voteCount =
          LobbyUtils.normalizePlayers(root['storyVotes']).length;
      final playerCount = _players.length;
      if (playerCount > 0 && voteCount >= playerCount) {
        _resolveAndAdvance();
      }
    }

    // 4. payload update
    if (_phase == StoryPhase.story && root['storyPayload'] != null) {
      final p = (root['storyPayload'] as Map).cast<String, dynamic>();
      _text    = p['initialLeg'] as String;
      _options = List<String>.from(p['options'] as List);
      _title   = p['storyTitle'] as String;
      notifyListeners();
    }

    // 5. detect kick (my UID gone)
    final stillHere =
    _players.values.any((p) => p['userId'] == _currentUid);
    if (!stillHere) {
      _error('You were removed from the session.');
    }
  }

  // ───────────────────────── vote helpers ─────────────────────────────────
  Future<void> _submitVote(String choice) async {
    try {
      await _lobbySvc.submitStoryVote(
        sessionId: sessionId!,
        vote: choice,
      );
      await _maybeAutoResolve();
    } catch (e) {
      _error('$e');
      await _rollbackToStoryPhase();
    }
  }

  Future<void> _maybeAutoResolve() async {
    if (!isHost || sessionId == null) return;
    final ref  = FirebaseDatabase.instance.ref('lobbies/$sessionId');
    final snap = await ref.get();
    final raw  = snap.value;
    if (raw is! Map) return;

    final players   = LobbyUtils.normalizePlayers(raw['players']);
    final votes     = LobbyUtils.normalizePlayers(raw['storyVotes']);
    final phaseEnum =
    StoryPhaseParsing.fromString(raw['phase']?.toString() ?? '');

    if (phaseEnum == StoryPhase.vote &&
        players.isNotEmpty &&
        votes.length >= players.length) {
      await _resolveAndAdvance();
    }
  }

  // ───────────────────────── solo helpers ─────────────────────────────────
  Future<void> _advanceSolo(String decision) async {
    try {
      final r = (decision == kPreviousLegToken)
          ? await _storySvc.getPreviousLeg()
          : await _storySvc.getNextLeg(decision: decision);

      _text    = r['storyLeg'] ?? 'No leg returned.';
      _options = List<String>.from(r['options'] ?? []);
      if (r.containsKey('storyTitle')) _title = r['storyTitle'];
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
      notifyListeners();
    } catch (e) {
      _error('$e');
    }
  }

  // ───────────────────────── vote resolution ─────────────────────────────
  Future<void> _resolveAndAdvance() async {
    _setBusy(true);
    try {
      await _lobbySvc.updatePhase(
        sessionId: sessionId!,
        phase: StoryPhase.results.asString,
      );

      final winner = await _lobbySvc.resolveStoryVotes(sessionId!);

      final nextPayload = (winner == kPreviousLegToken)
          ? await _storySvc.getPreviousLeg()
          : await _storySvc.getNextLeg(decision: winner);

      await _lobbySvc.advanceToStoryPhase(
        sessionId: sessionId!,
        storyPayload: {
          'initialLeg': nextPayload['storyLeg'],
          'options'   : List<String>.from(nextPayload['options'] ?? []),
          'storyTitle': nextPayload['storyTitle'],
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
          phase: StoryPhase.story.asString,
        );
      } catch (_) {}
    }
  }

  // ───────────────────────── misc helpers ─────────────────────────────────
  void _setBusy(bool v) {
    _busy = v;
    notifyListeners();
  }
}
