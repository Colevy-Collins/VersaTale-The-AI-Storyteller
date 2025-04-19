// lib/screens/create_new_story_screen.dart
// -----------------------------------------------------------------------------
// Updated for RTDB‑centric multiplayer flow (April 2025)
// -----------------------------------------------------------------------------
//  • Host flow:
//      – picks (or leaves random) dimension values
//      – calls backend to get {sessionId, joinCode}
//      – seeds RTDB lobby via LobbyRtdbService.createSession()
//  • Joiner flow:
//      – displays same UI to cast votes
//      – writes vote map to RTDB with LobbyRtdbService.submitVote()
//  • Solo flow unchanged.
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/dimension_map.dart';          // groupedDimensionOptions
import '../services/dimension_exclusions.dart';   // excludedDimensions list
import '../widgets/dimension_dropdown.dart';
import '../services/story_service.dart';          // still used for backend session creation
import '../services/lobby_rtdb_service.dart';
import 'story_screen.dart';
import 'multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  final bool isGroup;

  /// Populated when a **joiner** opened this screen from JoinMultiplayer.
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

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  /* ────────────────────────── services & state ───────────────────────── */

  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  bool   _loading  = false;
  int    _maxLegs  = 10;
  int    _optionCnt = 2;
  String _storyLen = 'Short';

  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices   = {}; // null = random
  final Map<String, bool>    _groupExpanded = {};

  @override
  void initState() {
    super.initState();
    _dimensionGroups = groupedDimensionOptions;
    _dimensionGroups.keys.forEach((g) => _groupExpanded[g] = false);
  }

  /* ────────────────────────── helpers ───────────────────────── */

  /// Returns a map of every dimension → chosenValue.
  /// If user didn’t pick, we supply a random option.
  Map<String, String> _randomDefaults() {
    final defs = <String, String>{};
    _dimensionGroups.forEach((_, g) {
      if (g is Map<String, dynamic>) {
        g.forEach((k, v) {
          if (v is List && !excludedDimensions.contains(k)) {
            defs[k] = _userChoices[k] ?? (List<String>.from(v)..shuffle()).first;
          }
        });
      }
    });
    return defs;
  }

  /// Vote payload = only the dimensions the user explicitly selected.
  Map<String, String> _votePayload() {
    final vote = <String, String>{};
    _userChoices.forEach((k, v) {
      if (v != null) vote[k] = v;
    });
    return vote;
  }

  /* ────────────────────────── SOLO flow ───────────────────────── */

  Future<void> _startSoloStory() async {
    setState(() => _loading = true);
    try {
      final res = await _storySvc.startStory(
        decision:      'Start Story',
        dimensionData: _randomDefaults(),
        maxLegs:       _maxLegs,
        optionCount:   _optionCnt,
        storyLength:   _storyLen,
      );
      if (!mounted) return;
      print('res: $res');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StoryScreen(
            initialLeg : res['storyLeg'],
            options    : List<String>.from(res['options'] ?? []),
            storyTitle : res['storyTitle'],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ────────────────────────── GROUP – host create ───────────────────────── */

  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      // 1) Ask backend for a fresh sessionId & joinCode (no story yet)
      final backendRes = await _storySvc.createMultiplayerSession("true");
      final sessionId  = backendRes['sessionId'] as String;
      final joinCode   = backendRes['joinCode']  as String;

      // 2) Seed RTDB lobby with host’s random defaults
      final hostName   = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
      await _lobbySvc.createSession(
        sessionId:      sessionId,
        hostName:       hostName,
        randomDefaults: _randomDefaults(),
        newGame:        true,
      );

      // 3) Build minimal playersMap (host only)
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final playersMap = <int, Map<String, dynamic>>{
        1: {'displayName': hostName, 'userId': currentUid},
      };

      // 4) Navigate to lobby
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId:     sessionId,
            joinCode:      joinCode,
            playersMap:    playersMap,
            fromSoloStory: false,
            fromGroupStory: false,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  /* ────────────────────────── GROUP – joiner vote ───────────────────────── */

  Future<void> _submitGroupVote() async {
    if (widget.sessionId == null || widget.joinCode == null || widget.initialPlayersMap == null)
      return;

    setState(() => _loading = true);
    try {
      await _lobbySvc.submitVote(
        sessionId: widget.sessionId!,
        vote: _votePayload(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId:  widget.sessionId!,
            joinCode:   widget.joinCode!,
            playersMap: widget.initialPlayersMap!,
            fromSoloStory: false,
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
  Widget build(BuildContext ctx) {
    final joiner = widget.isGroup && widget.sessionId != null;

    return LayoutBuilder(builder: (c, cons) {
      final w  = cons.maxWidth;
      final fs = (w * 0.03).clamp(14.0, 20.0);
      final grp = _buildGroupCards(fs);

      return Scaffold(
        backgroundColor: const Color(0xFFC27b31),
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Colors.white,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: fs),
                Text(
                  widget.isGroup
                      ? (joiner
                      ? 'Vote on Story Settings'
                      : 'Configure Group Story')
                      : 'Create Your New Adventure',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.atma(
                    fontSize: fs + 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: fs),
                ...grp,
                if (!joiner) ...[
                  _labeledCard('Number of Options:', _optionCountDropdown(fs), fs),
                  _labeledCard('Story Length:', _storyLenDropdown(fs), fs),
                  SizedBox(height: fs * 2),
                ],
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: joiner
              ? _submitGroupVote
              : (widget.isGroup ? _createGroupSession : _startSoloStory),
          label: Text(
            widget.isGroup
                ? (joiner ? 'Submit Votes' : 'Proceed to Lobby')
                : 'Start Story',
            style: GoogleFonts.atma(fontSize: fs, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFE7E6D9),
        ),
      );
    });
  }

  /* ─────────── UI helper widgets ─────────── */

  List<Widget> _buildGroupCards(double fs) {
    final List<Widget> cards = [];
    _dimensionGroups.forEach((group, dims) {
      if (excludedDimensions.contains(group) || dims is! Map<String, dynamic>) return;
      final dropdowns = _buildDimensionDropdowns(dims, fs);
      if (dropdowns.isEmpty) return;
      cards.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            color: const Color(0xFFE7E6D9),
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              key: PageStorageKey(group),
              title: Text(group, style: GoogleFonts.atma(fontSize: fs + 2, fontWeight: FontWeight.bold)),
              initiallyExpanded: _groupExpanded[group]!,
              onExpansionChanged: (e) => setState(() => _groupExpanded[group] = e),
              children: dropdowns,
            ),
          ),
        ),
      );
    });
    return cards;
  }

  List<Widget> _buildDimensionDropdowns(Map<String, dynamic> dims, double fs) {
    final List<Widget> widgets = [];
    dims.forEach((k, v) {
      if (excludedDimensions.contains(k) || v is! List) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DimensionDropdown(
            label: k,
            options: List<String>.from(v),
            initialValue: _userChoices[k],
            onChanged: (val) => setState(() => _userChoices[k] = val),
          ),
        ),
      );
    });
    return widgets;
  }

  Widget _optionCountDropdown(double fs) => DropdownButton<int>(
    value: _optionCnt,
    isExpanded: true,
    style: GoogleFonts.atma(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87),
    items: [2, 3, 4].map((c) => DropdownMenuItem(value: c, child: Text('$c'))).toList(),
    onChanged: (v) => setState(() => _optionCnt = v!),
  );

  Widget _storyLenDropdown(double fs) => DropdownButton<String>(
    value: _storyLen,
    isExpanded: true,
    style: GoogleFonts.atma(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87),
    items: ['Short', 'Medium', 'Long'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
    onChanged: (v) => setState(() => _storyLen = v!),
  );

  Widget _labeledCard(String label, Widget child, double fs) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Card(
        color: const Color(0xFFE7E6D9),
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.atma(fontSize: fs, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 8),
            child,
          ]),
        ),
      ),
    ),
  );
}
