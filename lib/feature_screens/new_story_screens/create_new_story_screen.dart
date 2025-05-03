// lib/screens/new_story_screens/create_new_story_screen.dart
// -----------------------------------------------------------------------------
// Lets the user (solo or host) pick dimension values and launch a story.
// Fully responsive down to watch‑sized 240 × 340 displays. Dimensions named in
// excludedDimensions are **hidden from the UI** yet still get random values
// when a story starts or a vote is submitted.
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/dimension_map.dart';        // groupedDimensionOptions
import '../../services/dimension_exclusions.dart'; // excludedDimensions
import '../../widgets/dimension_picker.dart';
import '../../services/story_service.dart';
import '../../services/lobby_rtdb_service.dart';
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
  int    _maxLegs   = 10;
  int    _optionCnt = 2;
  String _storyLen  = 'Short';

  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices   = {}; // null ⇒ random
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

  /// Copy of `_dimensionGroups` with every dimension in `excludedDimensions`
  /// removed.  Groups that become empty are dropped entirely.
  Map<String, dynamic> _visibleGroups() {
    final out = <String, Map<String, dynamic>>{};

    _dimensionGroups.forEach((groupName, group) {
      if (group is Map<String, dynamic>) {
        final filtered = Map<String, dynamic>.from(group)
          ..removeWhere((dim, _) => excludedDimensions.contains(dim));
        if (filtered.isNotEmpty) out[groupName] = filtered;
      }
    });

    return out;
  }

  /* ───────── helper maps ───────── */

  /// Picks a random value for every dimension the user left as “random”.
  /// (Hidden dimensions are *always* random because the user never sees them.)
  Map<String, String> _randomDefaults() {
    final defs = <String, String>{};

    _dimensionGroups.forEach((_, group) {
      if (group is Map<String, dynamic>) {
        group.forEach((dim, values) {
          if (values is List) {
            defs[dim] =
                _userChoices[dim] ?? (List<String>.from(values)..shuffle()).first;
          }
        });
      }
    });

    return defs;
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
        maxLegs      : _maxLegs,
        optionCount  : _optionCnt,
        storyLength  : _storyLen,
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
                              groups   : _visibleGroups(),  // <── filtered
                              choices  : _userChoices,
                              expanded : _groupExpanded,
                              onExpand : (k, open) =>
                                  setState(() => _groupExpanded[k] = open),
                              onChanged: (dim, val) =>
                                  setState(() => _userChoices[dim] = val),
                            ),
                          ),
                        ),

                        /* ───── additional settings (solo / host) ───── */
                        if (!joiner) ...[
                          _labeledCard(
                            'Minimum Number of Options:',
                            _optionCountDropdown(fs),
                            fs,
                            textColor,
                            tt,
                          ),
                          _labeledCard(
                            'Story Length:',
                            _storyLengthDropdown(fs),
                            fs,
                            textColor,
                            tt,
                          ),
                          SizedBox(height: fs * 2),
                        ],
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

  /* ───────── helper widgets ───────── */

  Widget _optionCountDropdown(double fs) => DropdownButtonFormField<int>(
    value: _optionCnt,
    isExpanded: true,
    onChanged : (v) => setState(() => _optionCnt = v!),
    items     : [2, 3, 4]
        .map((c) => DropdownMenuItem(value: c, child: Text('$c')))
        .toList(),
  );

  Widget _storyLengthDropdown(double fs) => DropdownButtonFormField<String>(
    value: _storyLen,
    isExpanded: true,
    onChanged : (v) => setState(() => _storyLen = v!),
    items     : ['Short', 'Medium', 'Long']
        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
        .toList(),
  );

  Widget _labeledCard(
      String label,
      Widget child,
      double fs,
      Color textColor,
      TextTheme tt,
      ) =>
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.bodyLarge?.copyWith(
                      fontSize: fs,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ),
        ),
      );
}
