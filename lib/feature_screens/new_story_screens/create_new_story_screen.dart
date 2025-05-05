// lib/screens/new_story_screens/create_new_story_screen.dart
// -----------------------------------------------------------------------------
// Story‑setup screen (solo + multiplayer host/joiner)
// • Parchment background sizes with content and repeats vertically.
// • Joiners can vote; hosts configure all dimensions.
// • Accent‑coloured CTA button; no black bar.
// • Page title is always ON the scroll, on ONE line, and scales smoothly.
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/story_phase.dart';
import '../../services/dimension_map.dart';
import '../../services/dimension_exclusions.dart';
import '../../services/joiner_dimension_exclusions.dart' as joiner_excl;
import '../../services/story_service.dart';
import '../../services/lobby_rtdb_service.dart';

import '../../utils/dimension_utils.dart';
import '../../widgets/dimension_picker.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/parchment_background.dart';

import '../story_screen.dart';
import '../multiplayer_screens/multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  const CreateNewStoryScreen({
    super.key,
    required this.isGroup,
    this.sessionId,
    this.joinCode,
    this.initialPlayersMap,
  });

  final bool isGroup;
  final String? sessionId; // non‑null ⇒ joinermode
  final String? joinCode;
  final Map<int, Map<String, dynamic>>? initialPlayersMap;

  @override
  State<CreateNewStoryScreen> createState() => _CreateNewStoryScreenState();
}

/* ─────────────────────────────────────────────────────────────────────── */

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
/* ───────── services ───────── */
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

/* ───────── state ───────── */
  bool _loading = false;

  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices = {};
  final Map<String, bool> _groupExpanded = {};

/* ───────────────────────── lifecycle ───────────────────────── */

  @override
  void initState() {
    super.initState();
    _dimensionGroups = groupedDimensionOptions;
    for (final g in _dimensionGroups.keys) {
      _groupExpanded[g] = false;
    }
  }

/* ───────────────────────── helpers ───────────────────────── */

  /// Font size that scales with the scroll/card width yet stays readable.
  double _titleFont(double cardMaxW) {
    // 240px → ~14, 300px →16, 400px →22, 500px →≈26
    const double minFs = 14;
    const double maxFs = 26;
    final double raw   = cardMaxW / 18;
    return raw.clamp(minFs, maxFs).toDouble();
  }

  Map<String, dynamic> _visibleGroups(bool forJoiner) {
    final blacklist = forJoiner
        ? joiner_excl.joinerExcludedDimensions
        : excludedDimensions;

    Map<String, dynamic> strip(Map<String, dynamic> node) {
      final filtered = Map<String, dynamic>.from(node)
        ..removeWhere((k, _) => blacklist.contains(k));

      final out = <String, dynamic>{};
      filtered.forEach((k, v) {
        if (v is Map<String, dynamic>) {
          final nested = strip(v);
          if (nested.isNotEmpty) out[k] = nested;
        } else {
          out[k] = v;
        }
      });
      return out;
    }

    final res = <String, dynamic>{};
    _dimensionGroups.forEach((g, n) {
      final cleaned = strip(n as Map<String, dynamic>);
      if (cleaned.isNotEmpty) res[g] = cleaned;
    });
    return res;
  }

  Map<String, String> _randomDefaults() => DimensionUtils.randomDefaults(
    dimensionGroups: _dimensionGroups,
    userChoices: _userChoices,
  );

  Map<String, String> _votePayload() {
    final v = <String, String>{};
    _userChoices.forEach((k, val) {
      if (val != null) v[k] = val;
    });
    return v;
  }

/* ───────────────────────── flows (unchanged) ───────────────────────── */

  Future<void> _startSoloStory() async {
    setState(() => _loading = true);
    try {
      final res = await _storySvc.startStory(
        decision: 'Start Story',
        dimensionData: _randomDefaults(),
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            initialLeg      : res['storyLeg'],
            options         : List<String>.from(res['options'] ?? []),
            storyTitle      : res['storyTitle'],
            inputTokens     : res['inputTokens'] ?? 0,
            outputTokens    : res['outputTokens'] ?? 0,
            estimatedCostUsd: res['estimatedCostUsd'] ?? 0.0,
          ),
        ),
      );
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      final backend = await _storySvc.createMultiplayerSession('true');
      final sessionId = backend['sessionId'] as String;
      final joinCode  = backend['joinCode']  as String;

      final hostName =
          FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
      await _lobbySvc.createSession(
        sessionId     : sessionId,
        hostName      : hostName,
        randomDefaults: _randomDefaults(),
        newGame       : true,
      );
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
            initialPlayers    : {
              1: {
                'displayName': hostName,
                'userId'     : FirebaseAuth.instance.currentUser?.uid ?? '',
              }
            },
            fromSoloStory : false,
            fromGroupStory: false,
          ),
        ),
      );
    } catch (e) {
      _snack('Failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _submitGroupVote() async {
    if (widget.sessionId == null) return;
    setState(() => _loading = true);
    try {
      await _lobbySvc.submitVote(
        sessionId: widget.sessionId!,
        vote     : _votePayload(),
      );
      await _lobbySvc.updatePhase(
        sessionId: widget.sessionId!,
        phase    : StoryPhase.lobby.asString,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId     : widget.sessionId!,
            joinCode      : widget.joinCode!,
            initialPlayers    : widget.initialPlayersMap!,
            fromSoloStory : false,
            fromGroupStory: false,
          ),
        ),
      );
    } catch (e) {
      _snack('Vote failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

/* ───────────────────────── UI ───────────────────────── */

  @override
  Widget build(BuildContext context) {
    final colours = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;

    final accent  = colours.secondary;
    final joiner  = widget.isGroup && widget.sessionId != null;

    return Scaffold(
      backgroundColor: colours.background,
      body: SafeArea(
        child: _loading
            ? Center(
          child: SizedBox(
            width : 48,
            height: 48,
            child : CircularProgressIndicator(
              strokeWidth: 6,
              color      : accent,
            ),
          ),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final tiny      = width < 320;
            final horizPad  = width <= 300 ? 8.0 : 16.0;
            final cardMaxW  = min(width - horizPad * 2, 500.0);

            final String pageTitle = widget.isGroup
                ? (joiner
                ? 'Vote on Story Settings'
                : 'Configure Group Story')
                : 'Create Your New Adventure';

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizPad,
                  vertical  : 24,
                ),
                child: ParchmentBackground(
                  contentWidth: cardMaxW,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: cardMaxW),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        /* ── New header: centred, 1‑line, scalable ── */
                        Row(
                          children: [
                            const AppBackButton(),
                            const SizedBox(width: 8),        // gap
                            Expanded(
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    pageTitle,
                                    maxLines : 1,
                                    style: tt.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize : _titleFont(cardMaxW),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 40),       // balance arrow
                          ],
                        ),
                        const SizedBox(height: 24),

                        /* ── Dimension picker ─────────── */
                        DimensionPicker(
                          groups         : _visibleGroups(joiner),
                          choices        : _userChoices,
                          expanded       : _groupExpanded,
                          readOnlyJoiner : false,
                          onExpandChanged: (g, open) =>
                              setState(() =>
                              _groupExpanded[g] = open),
                          onDimChanged   : (dim, val) =>
                              setState(() =>
                              _userChoices[dim] = val),
                        ),
                        const SizedBox(height: 32),

                        /* ── CTA button ───────────────── */
                        ElevatedButton(
                          onPressed: _loading
                              ? null
                              : (joiner
                              ? _submitGroupVote
                              : (widget.isGroup
                              ? _createGroupSession
                              : _startSoloStory)),
                          style: ElevatedButton.styleFrom(
                            minimumSize     : const Size.fromHeight(48),
                            backgroundColor : accent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            widget.isGroup
                                ? (joiner
                                ? (tiny ? 'Vote'
                                : 'Submit Votes')
                                : (tiny ? 'Lobby'
                                : 'Proceed to Lobby'))
                                : (tiny ? 'Start'
                                : 'Start Story'),
                            style: tt.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color     : colours.onSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

/* ───────────────────────── misc ───────────────────────── */

  void _snack(String msg) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
}
