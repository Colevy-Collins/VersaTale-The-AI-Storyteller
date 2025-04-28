// lib/screens/story_archives_screen.dart
// -----------------------------------------------------------------------------
// Lists the user’s saved stories (Firestore).  Each card now shows:
//   • when the story was last played
//   • total prompt / completion tokens
//   • running USD cost
// When the user presses “Continue” we pass those counters to StoryScreen so
// the badge is seeded correctly.
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/story_service.dart';
import 'story_screen.dart';

class ViewStoriesScreen extends StatefulWidget {
  const ViewStoriesScreen({Key? key}) : super(key: key);

  @override
  _ViewStoriesScreenState createState() => _ViewStoriesScreenState();
}

/* ────────────────────────────────────────────────────────────────────────── */

class _ViewStoriesScreenState extends State<ViewStoriesScreen> {
  final StoryService _storyService = StoryService();

  List<dynamic> _stories = [];
  bool   _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSavedStories();
  }

  Future<void> _fetchSavedStories() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _storyService.getSavedStories();
      setState(() => _stories = fetched);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return raw;
    }
  }

  /* ───────────────────────── Story actions ───────────────────────────── */

  Future<void> _viewStory(Map<String, dynamic> s) async {
    final details = await _storyService.viewStory(storyId: s['story_ID']);
    final content = details['initialLeg'] as String? ?? 'No content.';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title  : Text(details['storyTitle'] as String? ?? 'Story Details'),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadStory(s, content: content);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadStory(Map<String, dynamic> s, {String? content}) async {
    final data = content ??
        (await _storyService.viewStory(storyId: s['story_ID']))['initialLeg'] as String;
    final bytes  = utf8.encode(data);
    final blob   = html.Blob([bytes], 'text/plain');
    final url    = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = 'story_${s['storyTitle']}.txt';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _deleteStory(Map<String, dynamic> s) async {
    await _storyService.deleteStory(storyId: s['story_ID']);
    _fetchSavedStories();
  }

  Future<void> _continueStory(Map<String, dynamic> s) async {
    final cont = await _storyService.continueStory(storyId: s['story_ID']);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          initialLeg : cont['storyLeg'] as String,
          options    : List<String>.from(cont['options'] as List),
          storyTitle : cont['storyTitle'] as String,
          // ── seed counters so badge shows immediately ─────────────────
          inputTokens     : cont['inputTokens']     ?? 0,
          outputTokens    : cont['outputTokens']    ?? 0,
          estimatedCostUsd: cont['estimatedCostUsd']?? 0.0,
        ),
      ),
    );
  }

  /* ───────────────────────── Card builder ───────────────────────────── */

  Widget _buildStoryItem(Map<String, dynamic> s) {
    final size          = MediaQuery.of(context).size;
    final smallScreen   = size.width < 1038 || size.height < 925;
    final maxWidth      = smallScreen ? size.width * 0.9 : size.width * 0.35;

    final title = s['storyTitle'] as String? ?? 'Untitled Story';
    final time  = _formatTime(s['lastActivity'] as String? ?? 'Unknown');
    final inTok = s['inputTokens']  ?? 0;
    final outTok= s['outputTokens'] ?? 0;
    final cost  = (s['estimatedCostUsd'] ?? 0.0) as double;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 6,
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Colors.orange.shade50],
                begin : Alignment.topLeft,
                end   : Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(time,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600], fontSize: 12)),
                const SizedBox(height: 4),
                // NEW ─ usage badge
                Text('$inTok tok • \$${cost.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                          icon : Icon(Icons.visibility, color: Colors.blue.shade700),
                          label: Text('View', style: TextStyle(color: Colors.blue.shade700)),
                          onPressed: () => _viewStory(s)),
                      TextButton.icon(
                          icon : Icon(Icons.download_rounded, color: Colors.blue.shade700),
                          label: Text('Download', style: TextStyle(color: Colors.blue.shade700)),
                          onPressed: () => _downloadStory(s)),
                      TextButton.icon(
                          icon : Icon(Icons.delete_outline, color: Colors.blue.shade700),
                          label: Text('Delete', style: TextStyle(color: Colors.blue.shade700)),
                          onPressed: () => _deleteStory(s)),
                      ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          ),
                          icon : const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                          label: const Text('Continue', style: TextStyle(color: Colors.white)),
                          onPressed: () => _continueStory(s)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /* ───────────────────────── build UI ─────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final size        = MediaQuery.of(context).size;
    final smallScreen = size.width < 1038 || size.height < 925;

    // big decorative image vars
    const double bigW = 630;
    final double imgW = smallScreen ? size.width * 0.9 : bigW;
    final double imgH = imgW * 0.8;
    final double blur = smallScreen ? 0 : imgW * 0.03;
    final Offset shOffset = smallScreen ? Offset.zero : Offset(imgW * 0.02, imgH * 0.02);

    final storyImage = Container(
      width : imgW,
      height: imgH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: blur, offset: shOffset)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset('assets/reading.jpg', fit: BoxFit.contain),
      ),
    );

    final appBar = AppBar(
      backgroundColor: Colors.orange.shade200,
      title: Text('Saved Stories', style: Theme.of(context).textTheme.titleLarge),
    );

    /* ───────── empty state ───────── */
    if (!_isLoading && _stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.orange.shade50,
        appBar: appBar,
        body: Center(
          child: Text('You have no saved stories yet',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black12)),
        ),
      );
    }

    /* ───────── small-screen layout ───────── */
    if (smallScreen) {
      return Scaffold(
        backgroundColor: Colors.orange.shade50,
        appBar: appBar,
        body: RefreshIndicator(
          onRefresh: _fetchSavedStories,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var s in _stories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _buildStoryItem(s as Map<String, dynamic>),
                  ),
                const SizedBox(height: 24),
                storyImage,
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }

    /* ───────── large-screen layout ───────── */
    final double imageTop   = size.height * 0.18;
    final double cardsInset = imgH * 0.28;

    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      appBar: appBar,
      body: Stack(
        children: [
          Positioned(top: imageTop, right: 24, child: storyImage),
          Padding(
            padding: EdgeInsets.only(
              top: cardsInset,
              left: 16,
              right: 24 + bigW * 0.1,
            ),
            child: RefreshIndicator(
              onRefresh: _fetchSavedStories,
              child: ListView.separated(
                padding: const EdgeInsets.only(right: 24),
                itemCount: _stories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) =>
                    _buildStoryItem(_stories[i] as Map<String, dynamic>),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
