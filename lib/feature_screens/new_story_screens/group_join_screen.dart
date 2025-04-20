// lib/screens/host_story_config.dart
// -----------------------------------------------------------------------------
// Multiplayer Host: pick dimensions then seed RTDB lobby
// -----------------------------------------------------------------------------
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/dimension_map.dart';        // groupedDimensionOptions
import '../../services/dimension_exclusions.dart'; // excludedDimensions list
import '../../widgets/dimension_picker.dart';      // shared dimension UI
import '../../services/story_service.dart';        // backend session creation
import '../../services/lobby_rtdb_service.dart';  // RTDB lobby
import '../mutiplayer_screens/multiplayer_host_lobby_screen.dart';    // for navigation

class HostStoryConfig extends StatefulWidget {
  const HostStoryConfig({Key? key}) : super(key: key);

  @override
  _HostStoryConfigState createState() => _HostStoryConfigState();
}

class _HostStoryConfigState extends State<HostStoryConfig> {
  final _storySvc = StoryService();
  final _lobbySvc = LobbyRtdbService();

  bool _loading = false;
  late final Map<String, dynamic> _dimensionGroups;
  final Map<String, String?> _userChoices = {};  // null = random
  final Map<String, bool> _groupExpanded = {};

  @override
  void initState() {
    super.initState();
    _dimensionGroups = groupedDimensionOptions;
    for (var key in _dimensionGroups.keys) {
      _groupExpanded[key] = false;
    }
  }

  /// Supply random defaults for any unpicked dimension
  Map<String, String> _randomDefaults() {
    final defs = <String, String>{};
    _dimensionGroups.forEach((dim, group) {
      if (group is Map<String, dynamic>) {
        group.forEach((key, values) {
          if (values is List && !excludedDimensions.contains(key)) {
            defs[key] = _userChoices[key]
                ?? (List<String>.from(values)..shuffle()).first;
          }
        });
      }
    });
    return defs;
  }

  Future<void> _createGroupSession() async {
    setState(() => _loading = true);
    try {
      // 1) get sessionId & joinCode from backend
      final backendRes = await _storySvc.createMultiplayerSession('true');
      final sessionId = backendRes['sessionId'] as String;
      final joinCode = backendRes['joinCode'] as String;

      // 2) seed lobby with chosen/random dimensions
      final hostName = FirebaseAuth.instance.currentUser?.displayName ?? 'Host';
      await _lobbySvc.createSession(
        sessionId: sessionId,
        hostName: hostName,
        randomDefaults: _randomDefaults(),
        newGame: true,
      );

      // 3) navigate to lobby screen
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MultiplayerHostLobbyScreen(
            sessionId: sessionId,
            joinCode: joinCode,
            playersMap: {1: {'displayName': hostName, 'userId': FirebaseAuth.instance.currentUser?.uid ?? ''}},
            fromSoloStory: false,
            fromGroupStory: true,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: \$e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFC27B31),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
          builder: (ctx, cons) {
            final fs = (cons.maxWidth * 0.03).clamp(14.0, 20.0);
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  SizedBox(height: fs),
                  Text(
                    'Configure Group Story',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.atma(
                      fontSize: fs + 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: fs * 1.5),

                  // dimension picking UI
                  DimensionPicker(
                    groups: _dimensionGroups,
                    choices: _userChoices,
                    expanded: _groupExpanded,
                    onExpand: (key, open) => setState(() => _groupExpanded[key] = open),
                    onChanged: (dim, val) => setState(() => _userChoices[dim] = val),
                  ),

                  SizedBox(height: fs * 2),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroupSession,
        label: Text(
          'Proceed to Lobby',
          style: GoogleFonts.atma(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE7E6D9),
      ),
    );
  }
}
