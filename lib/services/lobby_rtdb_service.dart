// lib/services/lobby_rtdb_service.dart
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../constants/story_tokens.dart';

/// Thrown on any RTDB or auth error in LobbyService.
class LobbyException implements Exception {
  final String message;
  LobbyException(this.message);
  @override
  String toString() => message;
}

class LobbyRtdbService {
  final _db   = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  /// Throws if there is no signed-in user.
  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw LobbyException('User is not authenticated.');
    return user.uid;
  }

  DatabaseReference _lobbyRef(String sessionId) =>
      _db.ref('lobbies/$sessionId');
  DatabaseReference get _lobbiesRoot => _db.ref('lobbies');

  /// Map known RTDB or custom plugin error codes to friendly messages.
  String _getFriendlyErrorMessage(FirebaseException e) {
    switch (e.code) {
      case 'HOST_CANNOT_JOIN':
        return 'You cannot join your own lobby. Create a different session or ask someone else to host.';
      case 'ALREADY_JOINED':
        return 'You’re already in this lobby. Ask the host to remove you before rejoining.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'network-error':
        return 'Network error. Please check your connection and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'database-read-only':
        return 'The lobby is currently read‑only. Try again later.';
      default:
        return e.message ?? 'Unexpected error [${e.code}].';
    }
  }

  /// Generic runner that catches and wraps Firebase errors.
  Future<T> _run<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on FirebaseException catch (e) {
      throw LobbyException(_getFriendlyErrorMessage(e));
    } catch (e) {
      throw LobbyException(e.toString());
    }
  }

  /// Normalize RTDB snapshot value into a flat String→dynamic map.
  Map<String, dynamic> _normalizeMap(dynamic raw) {
    final map = <String, dynamic>{};
    if (raw is Map) {
      map.addAll(Map<String, dynamic>.from(raw));
    } else if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final entry = raw[i];
        if (entry is Map) map['$i'] = Map<String, dynamic>.from(entry);
      }
    }
    return map;
  }

  Future<bool> _isAlreadyHosting() => _run<bool>(() async {
    final snap = await _lobbiesRoot
        .orderByChild('hostUid')
        .equalTo(_uid)
        .limitToFirst(1)
        .get();
    return snap.exists;
  });

  Future<void> createSession({
    required String sessionId,
    required String hostName,
    required Map<String, String> randomDefaults,
    required bool newGame,
  }) => _run<void>(() async {
    // Remove existing lobby you host
    final existing = await _lobbiesRoot
        .orderByChild('hostUid')
        .equalTo(_uid)
        .limitToFirst(1)
        .get();
    if (existing.exists) {
      final oldId = existing.children.first.key;
      if (oldId != null) {
        await _lobbiesRoot.child(oldId).remove();
      }
    }
    // Seed new lobby
    await _lobbyRef(sessionId).set({
      'hostUid': _uid,
      'phase': 'lobby',
      'votesResolved': false,
      'randomDefaults': randomDefaults,
      'isNewGame': newGame,
      'players': {
        '1': {
          'userId': _uid,
          'displayName': hostName,
        }
      },
    });
  });

  Future<void> joinSession({
    required String sessionId,
    required String displayName,
  }) => _run<void>(() async {
    final lobby = _lobbyRef(sessionId);

    // 1) Host can’t join
    final hostSnap = await lobby.child('hostUid').get();
    if (hostSnap.value == _uid) {
      throw FirebaseException(
        plugin: 'lobby_rtdb_service',
        code: 'HOST_CANNOT_JOIN',
        message: 'Host cannot join their own lobby.',
      );
    }

    // 2) Prevent duplicate
    final playersSnap = await lobby.child('players').get();
    final players = _normalizeMap(playersSnap.value);
    if (players.values.any((p) => p['userId'] == _uid)) {
      throw FirebaseException(
        plugin: 'lobby_rtdb_service',
        code: 'ALREADY_JOINED',
        message: 'You’re already in this lobby.',
      );
    }

    // 3) Append a new slot
    await lobby.child('players').runTransaction((raw) {
      final m = <String, dynamic>{}..addAll(_normalizeMap(raw));
      final next = m.keys
          .map((k) => int.tryParse(k) ?? 0)
          .fold(0, (a, b) => b > a ? b : a) +
          1;
      m['$next'] = {
        'userId': _uid,
        'displayName': displayName,
      };
      return Transaction.success(m);
    });
  });

  Future<void> updateMyName(String sessionId, String newName) =>
      _run<void>(() async {
        final playersRef = _lobbyRef(sessionId).child('players');
        final snap = await playersRef.get();
        final players = _normalizeMap(snap.value);

        final slot = players.entries
            .firstWhere(
              (e) => e.value['userId'] == _uid,
          orElse: () => throw LobbyException('You are not in this lobby.'),
        )
            .key;

        await playersRef.child(slot).child('displayName').set(newName);
      });

  Future<void> submitVote({
    required String sessionId,
    required Map<String, String> vote,
  }) => _run<void>(() async {
    await _lobbyRef(sessionId).child('votes').child(_uid).set(vote);
  });

  Stream<DatabaseEvent> lobbyStream(String sessionId) =>
      _lobbyRef(sessionId).onValue;

  Future<void> resolveVotes(String sessionId) => _run<void>(() async {
    final ref = _lobbyRef(sessionId);
    final data = (await ref.get()).value as Map? ?? {};

    final defaults = Map<String, String>.from((data['randomDefaults'] ?? {}) as Map);
    final rawVotes = (data['votes'] as Map?) ?? {};
    final counts = <String, Map<String, int>>{};

    rawVotes.forEach((uid, v) {
      final votes = Map<String, dynamic>.from(v);
      votes.forEach((dim, choice) {
        counts.putIfAbsent(dim, () => {});
        final m = counts[dim]!;
        final c = choice.toString();
        m[c] = (m[c] ?? 0) + 1;
      });
    });

    final rnd = Random();
    final resolved = <String, String>{};
    defaults.forEach((dim, hostDef) {
      final m = counts[dim] ?? {};
      if (m.isEmpty) {
        resolved[dim] = hostDef;
      } else if (m.length == 1) {
        resolved[dim] = m.keys.first;
      } else {
        final maxCnt = m.values.reduce((a, b) => a > b ? a : b);
        final tied = m.entries.where((e) => e.value == maxCnt).map((e) => e.key).toList();
        resolved[dim] = tied[rnd.nextInt(tied.length)];
      }
    });

    await ref.update({
      'resolvedDimensions': resolved,
      'votesResolved': true,
      'phase': 'voteResults',
    });
  });

  Future<void> leaveLobby(String sessionId) => _run<void>(() async {
    final lobby = _lobbyRef(sessionId);
    final playersSnap = await lobby.child('players').get();
    final players = _normalizeMap(playersSnap.value);

    final slot = players.entries
        .firstWhere((e) => e.value['userId'] == _uid, orElse: () => MapEntry('', null))
        .key;
    if (slot.isNotEmpty) {
      await lobby.child('players').child(slot).remove();
    }
    await lobby.child('votes').child(_uid).remove();
  });

  Future<void> submitStoryVote({
    required String sessionId,
    required String vote,
  }) => _run<void>(() async {
    await _lobbyRef(sessionId).child('storyVotes').child(_uid).set(vote);
  });

  Future<void> updatePhase({
    required String sessionId,
    required String phase,
    required bool isNewGame,
  }) => _run<void>(() async {
    await _lobbyRef(sessionId).child('phase').set(phase);
    await _lobbyRef(sessionId).child('isNewGame').set(isNewGame);
  });

  Future<void> advanceToStoryPhase({
    required String sessionId,
    required Map<String, dynamic> storyPayload,
  }) => _run<void>(() async {
    await _lobbyRef(sessionId).update({
      'storyPayload': storyPayload,
      'resolvedChoice': null,
      'phase': 'story',
    });
  });

  Future<void> setPhaseToStory({
    required String sessionId,
  }) => _run<void>(() async {
    await _lobbyRef(sessionId).child('phase').set('story');
  });

  Future<void> setPhaseTolobby({
    required String sessionId,
  }) => _run<void>(() async {
    await _lobbyRef(sessionId).child('phase').set('lobby');
  });

  Future<bool> checkNewGame({
    required String sessionId,
  }) => _run<bool>(() async {
    final v = (await _lobbyRef(sessionId).child('isNewGame').get()).value;
    return v == true;
  });

  Future<void> incrementInLobbyCount(String sessionId) => _run<void>(() async {
    await _lobbyRef(sessionId).child('inLobbyCount').runTransaction((c) {
      final curr = (c as int?) ?? 0;
      return Transaction.success(curr + 1);
    });
  });

  Future<Map<String, dynamic>?> fetchStoryPayload({
    required String sessionId,
  }) => _run<Map<String, dynamic>?>(() async {
    final snap = await _lobbyRef(sessionId).child('storyPayload').get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  });

  Future<void> decrementInLobbyCount(String sessionId) => _run<void>(() async {
    final ref = _lobbyRef(sessionId).child('inLobbyCount');
    final res = await ref.runTransaction((c) {
      final n = ((c as int?) ?? 0) - 1;
      return Transaction.success(n < 0 ? 0 : n);
    });
    final newCount = (res.snapshot.value as int?) ?? 0;
    if (newCount == 0) {
      await _lobbyRef(sessionId).child('phase').set('story');
    }
  });

  Future<void> kickPlayer({
    required String sessionId,
    required int slot,
  }) => _run<void>(() async {
    final lobby = _lobbyRef(sessionId);
    final snap = await lobby.child('players/$slot').get();
    if (snap.exists && snap.value is Map) {
      final userId = (snap.value as Map)['userId'] as String?;
      await lobby.child('players/$slot').remove();
      if (userId != null) {
        await lobby.child('votes').child(userId).remove();
      }
    }
  });

  Future<Map<String, dynamic>?> fetchStoryPayloadIfInStoryPhase({
    required String sessionId,
  }) => _run<Map<String, dynamic>?>(() async {
    final ref = _lobbyRef(sessionId);
    final phase = (await ref.child('phase').get()).value;
    if (phase != 'story') return null;
    final snap = await ref.child('storyPayload').get();
    if (!snap.exists || snap.value == null) return null;
    return Map<String, dynamic>.from(snap.value as Map);
  });

  Future<Map<int, Map<String, dynamic>>> fetchPlayerList({
    required String sessionId,
  }) => _run<Map<int, Map<String, dynamic>>>(() async {
    final snap = await _lobbyRef(sessionId).child('players').get();
    final flat = _normalizeMap(snap.value);
    final result = <int, Map<String, dynamic>>{};
    flat.forEach((k, v) {
      result[int.parse(k)] = Map<String, dynamic>.from(v);
    });
    return result;
  });

  Future<String> resolveStoryVotes(String sessionId) => _run<String>(() async {
    final ref = _lobbyRef(sessionId);
    final data = (await ref.get()).value as Map? ?? {};
    final votes = (data['storyVotes'] as Map?)?.cast<String, dynamic>() ?? {};
    final counts = <String, int>{};
    votes.values.forEach((v) {
      final ch = v.toString();
      counts[ch] = (counts[ch] ?? 0) + 1;
    });

    // tie-breaking
    final maxCnt = counts.values.fold(0, (a, b) => b > a ? b : a);
    var winners = counts.entries
        .where((e) => e.value == maxCnt)
        .map((e) => e.key)
        .toList();
    if (winners.length > 1 && winners.contains(kPreviousLegToken)) {
      winners.remove(kPreviousLegToken);
    }
    if (winners.isEmpty) winners = [kPreviousLegToken];
    final win = winners[Random().nextInt(winners.length)];

    await ref.update({
      'resolvedChoice': win,
      'phase': 'storyVoteResults',
      'storyVotes': null,
    });
    return win;
  });
}
