// lib/screens/create_new_story_screen.dart
// -----------------------------------------------------------------------------
// Lets the user (solo or host) pick dimension values and launch a story.
// When starting a solo story we now pass inputTokens / outputTokens / cost
// to StoryScreen so the badge is correct from the first leg.
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/dimension_map.dart';        // groupedDimensionOptions
import '../../services/dimension_exclusions.dart'; // excludedDimensions
import '../../widgets/dimension_picker.dart';
import '../../services/story_service.dart';
import '../../services/lobby_rtdb_service.dart';
import '../story_screen.dart';
import '../mutiplayer_screens/multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  final bool isGroup;

  /// Filled only when a joiner opened this screen from JoinMultiplayer
  final String? sessionId;
  final String? joinCode;
  final Map<int, Map<String, dynamic>>? initialPlayersMap;

  const CreateNewStoryScreen({
    super.key,
    required this.isGroup,
    this.sessionId,
    this.joinCode,
    this.initialPlayersMap,
  });

  @override
  State<CreateNewStoryScreen> createState() => _CreateNewStoryScreenState();
}

/* ────────────────────────────────────────────────────────────────────────── */

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  // services
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  // UI state
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

  /* ─────────────────────────── helpers ───────────────────────────── */

  /// Map<dim, chosenValue> (fills in random defaults)
  Map<String, String> _randomDefaults() {
    final defs = <String, String>{};
    _dimensionGroups.forEach((_, g) {
      if (g is Map<String, dynamic>) {
        g.forEach((k, v) {
          if (v is List && !excludedDimensions.contains(k)) {
            defs[k] = _userChoices[k] ??
                (List<String>.from(v)..shuffle()).first;
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

  /* ─────────────────────────── SOLO flow ─────────────────────────── */

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
            // ────── pass usage counters so badge shows immediately ──────
            inputTokens     : res['inputTokens']     ?? 0,
            outputTokens    : res['outputTokens']    ?? 0,
            estimatedCostUsd: res['estimatedCostUsd']?? 0.0,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ─────────────────────── GROUP – host create ─────────────────────── */

  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      // 1) fresh session from backend
      final backend   = await _storySvc.createMultiplayerSession("true");
      final sessionId = backend['sessionId'] as String;
      final joinCode  = backend['joinCode']  as String;

      // 2) seed lobby in RTDB
      final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
      await _lobbySvc.createSession(
        sessionId     : sessionId,
        hostName      : hostName,
        randomDefaults: _randomDefaults(),
        newGame       : true,
      );

      // 3) host + vote
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final playersMap = <int, Map<String, dynamic>>{
        1: {'displayName': hostName, 'userId': uid},
      };
      await _lobbySvc.submitVote(sessionId: sessionId, vote: _votePayload());

      // 4) route host to lobby
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId     : sessionId,
            joinCode      : joinCode,
            playersMap    : playersMap,
            fromSoloStory : false,
            fromGroupStory: false,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ─────────────── GROUP – joiner votes then goes to lobby ─────────── */

  Future<void> _submitGroupVote() async {
    if (widget.sessionId == null) return;
    setState(() => _loading = true);
    try {
      await _lobbySvc.submitVote(sessionId: widget.sessionId!, vote: _votePayload());
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
    final baseColor   = const Color(0xFFE3F2FD);
    final cardColor   = const Color(0xFFECF0F3);
    final accentColor = const Color(0xFFFFB74D);
    final textColor   = const Color(0xFF333333);
    final shadowColor = const Color(0xFFE0E0E0);

    final joiner = widget.isGroup && widget.sessionId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width     = constraints.maxWidth;
        final fs        = (width * 0.03).clamp(14.0, 20.0);
        final paddedW   = width - 32;
        final cardMaxW  = paddedW < 500.0 ? paddedW : 500.0;
        final bgImgW    = cardMaxW + 200.0;

        final screenTheme = Theme.of(context).copyWith(
          canvasColor: cardColor,
          cardTheme: CardTheme(
            color: cardColor,
            shadowColor: shadowColor,
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: cardColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(8)),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(backgroundColor: MaterialStateProperty.all(cardColor)),
          ),
        );

        return Theme(
          data: screenTheme,
          child: Scaffold(
            backgroundColor: baseColor,
            body: SafeArea(
              child: _loading
                  ? Center(
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(strokeWidth: 6, color: accentColor),
                ),
              )
                  : Stack(
                children: [
                  // parchment image
                  Center(
                    child: Opacity(
                      opacity: 0.6,
                      child: Image.asset('assets/best_scroll.jpg', width: bgImgW, fit: BoxFit.cover),
                    ),
                  ),
                  // main content
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          IconButton(icon: const Icon(Icons.arrow_back), color: textColor,
                              onPressed: () => Navigator.pop(context)),
                        ]),
                        SizedBox(height: fs * 1.5),
                        Text(
                          widget.isGroup
                              ? (joiner ? 'Vote on Story Settings' : 'Configure Group Story')
                              : 'Create Your New Adventure',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kottaOne(
                              fontSize: fs + 8, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        SizedBox(height: fs * 1.5),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: DimensionPicker(
                              groups: _dimensionGroups,
                              choices: _userChoices,
                              expanded: _groupExpanded,
                              onExpand: (k, open) => setState(() => _groupExpanded[k] = open),
                              onChanged: (dim, val) => setState(() => _userChoices[dim] = val),
                            ),
                          ),
                        ),
                        if (!joiner) ...[
                          _labeledCard('Number of Options:', _optionCountDropdown(fs), fs, textColor),
                          _labeledCard('Story Length:', _storyLengthDropdown(fs), fs, textColor),
                          SizedBox(height: fs * 2),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: joiner ? _submitGroupVote : (widget.isGroup ? _createGroupSession : _startSoloStory),
              label: Text(
                widget.isGroup ? (joiner ? 'Submit Votes' : 'Proceed to Lobby') : 'Start Story',
                style: GoogleFonts.kottaOne(fontSize: fs, fontWeight: FontWeight.bold, color: textColor),
              ),
              backgroundColor: accentColor,
              foregroundColor: textColor,
            ),
          ),
        );
      },
    );
  }

  /* ─────────────────── UI helper widgets ─────────────────────────── */

  Widget _optionCountDropdown(double fs) => DropdownButtonFormField<int>(
    value: _optionCnt,
    isExpanded: true,
    onChanged: (v) => setState(() => _optionCnt = v!),
    items: [2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('$c'))).toList(),
  );

  Widget _storyLengthDropdown(double fs) => DropdownButtonFormField<String>(
    value: _storyLen,
    isExpanded: true,
    onChanged: (v) => setState(() => _storyLen = v!),
    items: ['Short', 'Medium', 'Long'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
  );

  Widget _labeledCard(String label, Widget child, double fs, Color textColor) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.kottaOne(fontSize: fs, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
