// lib/services/lobby_rtdb_service.dart
// -----------------------------------------------------------------------------
// Service for managing multiplayer lobbies via Firebase Realtime Database.
// • Host seeds lobby: players/1, randomDefaults, phase, votesResolved
// • Joiners register under players/N
// • Players submit votes under votes/{uid}
// • Host resolves votes client‑side and writes resolvedDimensions + phase
// • Host advances to story by writing storyPayload + phase
// • All clients subscribe via lobbyStream to react in real‑time
// -----------------------------------------------------------------------------

import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../constants/story_tokens.dart';

class LobbyRtdbService {
  final _db   = FirebaseDatabase.instance;
  final _auth = FirebaseAuth.instance;

  DatabaseReference _lobbyRef(String sessionId) => _db.ref('lobbies/$sessionId');
  /// Host: create/seed a new lobby in RTDB.
  Future<void> createSession({
    required String sessionId,
    required String hostName,
    required Map<String, String> randomDefaults,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = FirebaseDatabase.instance.ref('lobbies/$sessionId');

    await ref.set({
      'phase'        : 'lobby',
      'votesResolved': false,
      'randomDefaults': randomDefaults,
      'players' : {
        '1': {
          'userId'     : uid,
          'displayName': hostName,
        }
      }
    });
  }

  /// Joiner: register self under next available slot.
  Future<void> joinSession({
    required String sessionId,
    required String displayName,
  }) async {
    final uid       = FirebaseAuth.instance.currentUser!.uid;
    final playersRef = FirebaseDatabase.instance.ref('lobbies/$sessionId/players');

    await playersRef.runTransaction((currentData) {
      // normalize whatever’s there into a Map<String,dynamic>
      final Map<String, dynamic> playersMap = {};

      if (currentData is Map) {
        currentData.forEach((k, v) => playersMap[k.toString()] = v);
      } else if (currentData is List) {
        for (var i = 0; i < currentData.length; i++) {
          final entry = currentData[i];
          if (entry is Map) {
            playersMap['$i'] = entry;
          }
        }
      }
      // else: null or something else, start fresh

      // update existing slot or append a new one
      final existing = playersMap.entries.firstWhere(
            (e) => e.value['userId'] == uid,
        orElse: () => const MapEntry('', {}),
      );
      if (existing.key.isNotEmpty) {
        playersMap[existing.key] = {
          'userId'     : uid,
          'displayName': displayName,
        };
      } else {
        final next = playersMap.keys
            .map((k) => int.tryParse(k) ?? 0)
            .fold(0, (mx, n) => n > mx ? n : mx) + 1;
        playersMap['$next'] = {
          'userId'     : uid,
          'displayName': displayName,
        };
      }

      // return the new map for the transaction
      return Transaction.success(playersMap);
    });
  }




  /// Player: change your display name (finds your slot and updates displayName).
  Future<void> updateMyName(String sessionId, String newName) async {
    final uid = _auth.currentUser!.uid;
    final playersRef = _lobbyRef(sessionId).child('players');
    final snap = await playersRef.get();

    // 1) Normalize the snapshot into a Dart map
    final raw = snap.value;
    final Map<String, dynamic> players;
    if (raw is Map) {
      players = Map<String, dynamic>.from(raw);
    } else if (raw is List) {
      players = {};
      for (var i = 0; i < raw.length; i++) {
        final entry = raw[i];
        if (entry is Map) {
          players['$i'] = Map<String, dynamic>.from(entry);
        }
      }
    } else {
      return; // no players yet
    }

    // 2) Find your slot
    String? mySlot;
    players.forEach((slot, info) {
      if (info['userId'] == uid) mySlot = slot;
    });
    if (mySlot == null) return; // you aren’t in the lobby

    // 3) Write the new name
    await playersRef.child(mySlot!).child('displayName').set(newName);
  }

  /// Player: submit or update your vote map.
  Future<void> submitVote({
    required String sessionId,
    required Map<String, String> vote,
  }) async {
    final uid = _auth.currentUser!.uid;
    final voteRef = _lobbyRef(sessionId).child('votes').child(uid);
    await voteRef.set(vote);
  }

  /// Stream the entire lobby node for real‑time updates.
  Stream<DatabaseEvent> lobbyStream(String sessionId) {
    return _lobbyRef(sessionId).onValue;
  }

  /// Host: tally all votes, compute resolution, and write to RTDB.
  Future<void> resolveVotes(String sessionId) async {
    final ref = _lobbyRef(sessionId);
    final snap = await ref.get();
    final data = (snap.value as Map?) ?? {};

    // Host defaults
    final randomDefaults = Map<String, String>.from(
        (data['randomDefaults'] ?? {}) as Map
    );

    // Gather votes
    final rawVotes = (data['votes'] as Map?) ?? {};
    final Map<String, Map<String,int>> counts = {};
    rawVotes.forEach((uid, v) {
      final votes = Map<String, dynamic>.from(v as Map);
      votes.forEach((dim, choice) {
        counts.putIfAbsent(dim, () => {});
        final m = counts[dim]!;
        final c = choice.toString();
        m[c] = (m[c] ?? 0) + 1;
      });
    });

    // Compute resolution
    final rnd = Random();
    final Map<String, String> resolved = {};
    randomDefaults.forEach((dim, hostDef) {
      final m = counts[dim];
      if (m == null || m.isEmpty) {
        resolved[dim] = hostDef;
      } else if (m.length == 1) {
        resolved[dim] = m.keys.first;
      } else {
        final maxCount = m.values.reduce((a,b) => a>b? a:b);
        final winners = m.entries.where((e)=>e.value==maxCount).map((e)=>e.key).toList();
        resolved[dim] = winners[rnd.nextInt(winners.length)];
      }
    });

    // Write results
    await ref.update({
      'resolvedDimensions': resolved,
      'votesResolved':      true,
      'phase':              'voteResults',
    });
  }

  /// Optional: leave the lobby (remove your player entry + votes).
  Future<void> leaveLobby(String sessionId) async {
    final uid = _auth.currentUser!.uid;
    final lobby = _lobbyRef(sessionId);
    final playersRef = lobby.child('players');
    final snap = await playersRef.get();
    if (snap.exists && snap.value is Map) {
      final players = Map<String,dynamic>.from(snap.value as Map);
      for (final slot in players.keys) {
        final info = Map<String,dynamic>.from(players[slot]);
        if (info['userId'] == uid) {
          await playersRef.child(slot).remove();
          break;
        }
      }
    }
    await lobby.child('votes').child(uid).remove();
  }

  /// Player: submit your vote on the next decision.
  /// Player: submit your vote for the next story decision.
  Future<void> submitStoryVote({
    required String sessionId,
    required String vote,
  }) async {
    final uid     = _auth.currentUser!.uid;
    final voteRef = _lobbyRef(sessionId).child('storyVotes').child(uid);
    await voteRef.set(vote);
  }

  /// Anyone: change the lobby phase.
  Future<void> updatePhase({
    required String sessionId,
    required String phase,
  }) async {
    await _lobbyRef(sessionId).update({'phase': phase});
  }

  /// Host: after picking the next leg, broadcast it to everyone.
  Future<void> advanceToStoryPhase({
    required String sessionId,
    required Map<String, dynamic> storyPayload,
  }) async {
    final ref = _lobbyRef(sessionId);
    await ref.update({
      'storyPayload': storyPayload,
      'phase':        'story',
    });
  }

  /// Host: tally all storyVotes, pick a winning choice, clear votes,
  /// and set phase to 'storyVoteResults'. Returns the winner.
  Future<String> resolveStoryVotes(String sessionId) async {
    final ref  = _lobbyRef(sessionId);
    final snap = await ref.get();
    final data = (snap.value as Map?)?.cast<String, dynamic>() ?? {};

    // 1. Count votes
    final votes   = (data['storyVotes'] as Map?)?.cast<String, dynamic>() ?? {};
    final counts  = <String,int>{};
    votes.values.forEach((v) {
      final choice = v.toString();
      counts[choice] = (counts[choice] ?? 0) + 1;
    });

    // 2. Identify top‑vote choices
    final maxCount = counts.values.fold(0, (a, b) => b > a ? b : a);
    var   winners  = counts.entries
        .where((e) => e.value == maxCount)
        .map((e) => e.key)
        .toList();

    /* ── 3. Special rule: "<<PREVIOUS_LEG>>" can’t win a tie ───────────── */
    if (winners.length > 1 && winners.contains(kPreviousLegToken)) {
      winners.remove(kPreviousLegToken);
    }
    if (winners.isEmpty) {
      // This happens only when previous‑leg was removed from a tie,
      // so it must have been the sole remaining candidate originally.
      winners = [kPreviousLegToken];
    }

    // 4. Pick the winner (random if >1 remaining)
    final winner = winners[Random().nextInt(winners.length)];

    // 5. Write result & clean up
    await ref.update({
      'resolvedChoice': winner,
      'phase'         : 'storyVoteResults',
    });
    await ref.child('storyVotes').remove();      // clear votes
    return winner;
  }




}