// lib/screens/create_new_story_screen.dart
// -----------------------------------------------------------------------------
// “Serene Sky” palette: pale blue background, light cards (#ECF0F3),
// soft orange accents. Adds a parchment scroll image behind the title and cards,
// scaled to be slightly wider than the card content (max 500px + padding).
// -----------------------------------------------------------------------------

import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/dimension_map.dart';        // groupedDimensionOptions
import '../../services/dimension_exclusions.dart'; // excludedDimensions list
import '../../widgets/dimension_picker.dart';
import '../../services/story_service.dart';        // backend session creation
import '../../services/lobby_rtdb_service.dart';  // RTDB
import '../story_screen.dart';
import '../mutiplayer_screens/multiplayer_host_lobby_screen.dart';

class CreateNewStoryScreen extends StatefulWidget {
  final bool isGroup;
  final String? sessionId;
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
  _CreateNewStoryScreenState createState() => _CreateNewStoryScreenState();
}

class _CreateNewStoryScreenState extends State<CreateNewStoryScreen> {
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  bool _loading = false;
  int _optionCount = 2;
  String _storyLength = 'Short';

  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices = {};
  final Map<String, bool> _groupExpanded = {};

  @override
  void initState() {
    super.initState();
    _dimensionGroups = groupedDimensionOptions;
    for (var key in _dimensionGroups.keys) {
      _groupExpanded[key] = false;
    }
  }

  Map<String, String> _randomDefaults() {
    final defs = <String, String>{};
    _dimensionGroups.forEach((dim, group) {
      if (group is Map<String, dynamic>) {
        group.forEach((key, values) {
          if (values is List && !excludedDimensions.contains(key)) {
            defs[key] = _userChoices[key] ??
                (List<String>.from(values)
                  ..shuffle()).first;
          }
        });
      }
    });
    return defs;
  }

  Map<String, String> _votePayload() {
    final payload = <String, String>{};
    _userChoices.forEach((k, v) {
      if (v != null) payload[k] = v;
    });
    return payload;
  }

  Future<void> _startSoloStory() async {
    setState(() => _loading = true);
    try {
      final res = await _storySvc.startStory(
        decision: 'Start Story',
        dimensionData: _randomDefaults(),
        maxLegs: 10,
        optionCount: _optionCount,
        storyLength: _storyLength,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              StoryScreen(
                initialLeg: res['storyLeg'],
                options: List<String>.from(res['options'] ?? []),
                storyTitle: res['storyTitle'],
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

  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      final backendRes = await _storySvc.createMultiplayerSession('true');
      final sessionId = backendRes['sessionId'] as String;
      final joinCode = backendRes['joinCode'] as String;

      final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
      await _lobbySvc.createSession(
        sessionId: sessionId,
        hostName: hostName,
        randomDefaults: _randomDefaults(),
        newGame: true,
      );

      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final playersMap = {1: {'displayName': hostName, 'userId': currentUid}};

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MultiplayerHostLobbyScreen(
                sessionId: sessionId,
                joinCode: joinCode,
                playersMap: playersMap,
                fromSoloStory: false,
                fromGroupStory: false,
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

  Future<void> _submitGroupVote() async {
    if (widget.sessionId == null || widget.joinCode == null ||
        widget.initialPlayersMap == null) return;

    setState(() => _loading = true);
    try {
      await _lobbySvc.submitVote(
          sessionId: widget.sessionId!, vote: _votePayload());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              MultiplayerHostLobbyScreen(
                sessionId: widget.sessionId!,
                joinCode: widget.joinCode!,
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

  @override
  Widget build(BuildContext context) {
    // Serene Sky palette
    final baseColor = const Color(0xFFE3F2FD);
    final cardColor = const Color(0xFFECF0F3);
    final accentColor = const Color(0xFFFFB74D);
    final textColor = const Color(0xFF333333);
    final shadowColor = const Color(0xFFE0E0E0);

    final joiner = widget.isGroup && widget.sessionId != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fs = (width * 0.03).clamp(14.0, 20.0);

        // Calculate content width (screen minus horizontal padding)
        final double paddedWidth = width -
            32; // screen minus 16px padding each side
        final double cardMaxWidth = paddedWidth < 500.0 ? paddedWidth : 500.0;
        final double bgImageWidth = cardMaxWidth +
            200.0; // slightly wider than cards // 16px padding each side

        final screenTheme = Theme.of(context).copyWith(
          canvasColor: cardColor,
          cardTheme: CardTheme(
            color: cardColor,
            shadowColor: shadowColor,
            elevation: 2,
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
          dropdownMenuTheme: DropdownMenuThemeData(
            menuStyle: MenuStyle(
                backgroundColor: MaterialStateProperty.all(cardColor)),
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
                  child: CircularProgressIndicator(
                      strokeWidth: 6, color: accentColor),
                ),
              )
                  : Stack(
                children: [
                  // Background parchment image scaled to bgImageWidth
                  Center(
                    child: Opacity(
                      opacity: 0.6,
                      child: Image.asset(
                        'assets/best_scroll.jpg',
                        width: bgImageWidth,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Main content
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          IconButton(icon: const Icon(Icons.arrow_back),
                              color: textColor,
                              onPressed: () => Navigator.pop(context)),
                        ]),
                        SizedBox(height: fs * 1.5),
                        Text(
                          widget.isGroup
                              ? (joiner
                              ? 'Vote on Story Settings'
                              : 'Configure Group Story')
                              : 'Create Your New Adventure',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.kottaOne(fontSize: fs + 8,
                              fontWeight: FontWeight.bold,
                              color: textColor),
                        ),
                        SizedBox(height: fs * 1.5),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 450),
                            child: DimensionPicker(
                              groups: _dimensionGroups,
                              choices: _userChoices,
                              expanded: _groupExpanded,
                              onExpand: (k, open) =>
                                  setState(() => _groupExpanded[k] = open),
                              onChanged: (dim, val) =>
                                  setState(() => _userChoices[dim] = val),
                            ),
                          ),
                        ),
                        if (!joiner) ...[
                          _labeledCard(
                              'Number of Options:', _optionCountDropdown(fs),
                              fs, textColor),
                          _labeledCard(
                              'Story Length:', _storyLengthDropdown(fs), fs,
                              textColor),
                          SizedBox(height: fs * 2),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: joiner ? _submitGroupVote : (widget.isGroup
                  ? _createGroupSession
                  : _startSoloStory),
              label: Text(widget.isGroup ? (joiner
                  ? 'Submit Votes'
                  : 'Proceed to Lobby') : 'Start Story',
                  style: GoogleFonts.kottaOne(fontSize: fs,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
              backgroundColor: accentColor,
              foregroundColor: textColor,
            ),
          ),
        );
      },
    );
  }

  Widget _optionCountDropdown(double fs) =>
      DropdownButtonFormField<int>(
        value: _optionCount,
        isExpanded: true,
        onChanged: (v) => setState(() => _optionCount = v!),
        items: [2, 3, 4].map((c) =>
            DropdownMenuItem(value: c, child: Text('$c'))).toList(),
      );

  Widget _storyLengthDropdown(double fs) =>
      DropdownButtonFormField<String>(
        value: _storyLength,
        isExpanded: true,
        onChanged: (v) => setState(() => _storyLength = v!),
        items: ['Short', 'Medium', 'Long'].map((s) =>
            DropdownMenuItem(value: s, child: Text(s))).toList(),
      );

  Widget _labeledCard(String label, Widget child, double fs, Color textColor) =>
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.kottaOne(fontSize: fs,
                      fontWeight: FontWeight.bold,
                      color: textColor)),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            ),
          ),
        ),
      );

}