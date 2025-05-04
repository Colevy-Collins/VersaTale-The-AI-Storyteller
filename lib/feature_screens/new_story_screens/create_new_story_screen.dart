// -----------------------------------------------------------------------------
// Lets the user (solo or host) pick dimension values and launch a story.
// Fully responsive down to watch‑sized 240 × 340 displays.
//
// • Dimensions listed in `dimension_exclusions.dart` are always hidden.
// • When the player is a **joiner** (has a sessionId) we also hide any
//   dimension in `joiner_dimension_exclusions.dart`, so only the host
//   can set them.
//
// • “Minimum Number of Options” and “Story Length” no longer receive a
//   random value – they fall back to fixed defaults (2 / Short) unless
//   the host explicitly changes them.
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/dimension_map.dart';           // groupedDimensionOptions
import '../../services/dimension_exclusions.dart';    // excludedDimensions
import '../../services/joiner_dimension_exclusions.dart' as joiner_excl;                                   // joinerExcludedDimensions
import '../../widgets/dimension_picker.dart';
import '../../services/story_service.dart';
import '../../services/lobby_rtdb_service.dart';
import '../../models/story_phase.dart';
import '../story_screen.dart';
import '../mutiplayer_screens/multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  final bool isGroup;
  final String? sessionId;                       // join‑flow params
  final String? joinCode;
  final Map<int, Map<String, dynamic>>? initialPlayersMap;

  const CreateNewStoryScreen({
    Key? key,
    required this.isGroup,
    this.sessionId,
    this.joinCode,
    this.initialPlayersMap,
  }) : super(key: key);

  @override
  State<CreateNewStoryScreen> createState() => _CreateNewStoryScreenState();
}

/* ──────────────────────────────────────────────────────────────────────── */

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  /* ───────── services ───────── */
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  /* ───────── UI state ───────── */
  bool   _loading   = false;

  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices   = {}; // null ⇒ random / default
  final Map<String, bool>    _groupExpanded = {};

  @override
  void initState() {
    super.initState();
    _dimensionGroups = groupedDimensionOptions;
    for (final g in _dimensionGroups.keys) {
      _groupExpanded[g] = false;
    }
  }

  /* ───────── helper: groups without excluded dimensions ───────── */

  /// Copy of `_dimensionGroups` with every dimension in the current
  /// exclusion list removed.  Groups that become empty are dropped.
  Map<String, dynamic> _visibleGroups(bool forJoiner) {
    final List<String> blacklist = forJoiner
        ? joiner_excl.joinerExcludedDimensions
        : excludedDimensions;

    // Recursive helper to filter a map at all levels
    Map<String, dynamic> _filterMap(Map<String, dynamic> map) {
      // 1) remove excluded keys at this level
      final filtered = Map<String, dynamic>.from(map)
        ..removeWhere((key, _) => blacklist.contains(key));

      // 2) for each entry, if it’s a map, recurse; otherwise keep as‑is
      final result = <String, dynamic>{};
      filtered.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final nested = _filterMap(value);
          if (nested.isNotEmpty) result[key] = nested;
        } else {
          result[key] = value;
        }
      });

      return result;
    }

    final out = <String, dynamic>{};

    _dimensionGroups.forEach((groupName, group) {
      if (group is Map<String, dynamic>) {
        final cleaned = _filterMap(group);
        if (cleaned.isNotEmpty) out[groupName] = cleaned;
      }
    });

    return out;
  }

  /* ───────── helper maps ───────── */
  /// Flattens an arbitrarily nested map into path → List<String>
  /// where each path ends at a leaf list or scalar.
  /// Path segments are joined with dots.
  Map<String, List<String>> _flattenLeaves(dynamic node,
      [String prefix = '']) {
    final out = <String, List<String>>{};

    void recurse(dynamic n, String path) {
      if (n is Map<String, dynamic>) {
        n.forEach((k, v) => recurse(
          v,
          path.isEmpty ? k : '$path.$k',
        ));
      } else if (n is Iterable) {
        out[path] = n.map((e) => e.toString()).toList();
      } else {
        out[path] = [n.toString()];
      }
    }

    recurse(node, prefix);
    return out;
  }

  /// Picks a value for every leaf dimension the user left blank.
  /// * For most dimensions the value is random.
  /// * “Minimum Number of Options” defaults to **2**.
  /// * “Story Length” defaults to **Short**.
  /// Keys in the returned map are **leaf names only**.
  Map<String, String> _randomDefaults() {
    final rand     = Random();
    final defaults = <String, String>{};

    // path → [options]
    final leaves = _flattenLeaves(_dimensionGroups);

    leaves.forEach((path, options) {
      final leafKey = path.split('.').last; // keep only the tail
      if (leafKey == 'Minimum Number of Options') {
        defaults[leafKey] = _userChoices[leafKey] ?? '2';
      } else if (leafKey == 'Story Length') {
        defaults[leafKey] = _userChoices[leafKey] ?? 'Short';
      } else {
        defaults[leafKey] = _userChoices[leafKey] ??
            options[rand.nextInt(options.length)];
      }
    });

    return defaults;
  }

  /// Only the dimensions explicitly picked by the user (for votes)
  Map<String, String> _votePayload() {
    final v = <String, String>{};
    _userChoices.forEach((k, val) {
      if (val != null) v[k] = val;
    });
    return v;
  }

  /* ─────────────── SOLO flow ─────────────── */

  Future<void> _startSoloStory() async {
    setState(() => _loading = true);
    try {
      final res = await _storySvc.startStory(
        decision     : 'Start Story',
        dimensionData: _randomDefaults(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            initialLeg : res['storyLeg'],
            options    : List<String>.from(res['options'] ?? []),
            storyTitle : res['storyTitle'],
            inputTokens     : res['inputTokens']     ?? 0,
            outputTokens    : res['outputTokens']    ?? 0,
            estimatedCostUsd: res['estimatedCostUsd']?? 0.0,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ───── GROUP – host create ───── */

  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      final backend   = await _storySvc.createMultiplayerSession("true");
      final sessionId = backend['sessionId'] as String;
      final joinCode  = backend['joinCode']  as String;

      final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
      await _lobbySvc.createSession(
        sessionId     : sessionId,
        hostName      : hostName,
        randomDefaults: _randomDefaults(),
        newGame       : true,
      );

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _lobbySvc.submitVote(
        sessionId: sessionId,
        vote     : _votePayload(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId     : sessionId,
            joinCode      : joinCode,
            playersMap    : {1: {'displayName': hostName, 'userId': uid}},
            fromSoloStory : false,
            fromGroupStory: false,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ───── GROUP – joiner vote ───── */

  Future<void> _submitGroupVote() async {
    if (widget.sessionId == null) return;
    setState(() => _loading = true);
    try {
      await _lobbySvc.submitVote(
        sessionId: widget.sessionId!,
        vote     : _votePayload(),
      );

      await _lobbySvc.updatePhase(
          sessionId: widget.sessionId!, phase: StoryPhase.lobby.asString);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId     : widget.sessionId!,
            joinCode      : widget.joinCode!,
            playersMap    : widget.initialPlayersMap!,
            fromSoloStory : false,
            fromGroupStory: false,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vote failed: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ───────────────────────────── UI ───────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;

    final cardColor   = colours.surface;
    final accentColor = colours.secondary;
    final textColor   = colours.onBackground;
    final shadowColor = Theme.of(context).shadowColor;

    final joiner = widget.isGroup && widget.sessionId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width  = constraints.maxWidth;

        final bool   tinyScreen = width < 320;
        final double fs = tinyScreen
            ? max(width * 0.04, 10)
            : (width * 0.03).clamp(14.0, 20.0);

        final double paddedW  = width - 32;
        final double cardMaxW = min(paddedW, 500.0);
        final double bgImgW   = cardMaxW + 200.0;

        final screenTheme = Theme.of(context).copyWith(
          canvasColor: cardColor,
          cardTheme: CardTheme(
            color  : cardColor,
            shadowColor: shadowColor,
            elevation  : 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );

        return Theme(
          data: screenTheme,
          child: Scaffold(
            backgroundColor: colours.background,
            body: SafeArea(
              child: _loading
                  ? Center(
                child: SizedBox(
                  width : 48,
                  height: 48,
                  child : CircularProgressIndicator(
                    strokeWidth: 6,
                    color: accentColor,
                  ),
                ),
              )
                  : Stack(
                clipBehavior: Clip.none,
                children: [
                  // parchment background (ignores touches)
                  IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: 0.6,
                        child : Image.asset(
                          'assets/best_scroll.jpg',
                          width: bgImgW,
                          fit  : BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  // main content
                  SingleChildScrollView(
                    primary : true,
                    physics : const AlwaysScrollableScrollPhysics(),
                    padding : const EdgeInsets.all(16),
                    child   : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        /* ───── back button ───── */
                        Row(
                          children: [
                            IconButton(
                              icon : const Icon(Icons.arrow_back),
                              color: textColor,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        SizedBox(height: fs * 1.5),

                        /* ───── title ───── */
                        Text(
                          widget.isGroup
                              ? (joiner
                              ? 'Vote on Story Settings'
                              : 'Configure Group Story')
                              : 'Create Your New Adventure',
                          textAlign: TextAlign.center,
                          style: tt.headlineSmall?.copyWith(
                            fontSize: fs + 8,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: fs * 1.5),

                        /* ───── dimension picker ───── */
                        Center(
                          child: ConstrainedBox(
                            constraints:
                            BoxConstraints(maxWidth: cardMaxW),
                            child: DimensionPicker(
                              groups   : _visibleGroups(joiner),
                              choices  : _userChoices,
                              expanded : _groupExpanded,
                              onExpand : (k, open) =>
                                  setState(() =>
                                  _groupExpanded[k] = open),
                              onChanged: (dim, val) =>
                                  setState(() =>
                                  _userChoices[dim] = val),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /* ───────── FAB ───────── */
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: accentColor,
              foregroundColor: colours.onSecondary,
              onPressed: joiner
                  ? _submitGroupVote
                  : (widget.isGroup
                  ? _createGroupSession
                  : _startSoloStory),
              label: Text(
                widget.isGroup
                    ? (joiner
                    ? (tinyScreen ? 'Vote'  : 'Submit Votes')
                    : (tinyScreen ? 'Lobby' : 'Proceed to Lobby'))
                    : (tinyScreen ? 'Start' : 'Start Story'),
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      },
    );
  }
}
