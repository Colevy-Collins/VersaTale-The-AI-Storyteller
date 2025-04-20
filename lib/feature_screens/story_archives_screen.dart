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

class _ViewStoriesScreenState extends State<ViewStoriesScreen> {
  final StoryService _storyService = StoryService();
  List<dynamic> _stories = [];
  bool _isLoading = false;
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

  String _formatTime(String rawTime) {
    try {
      final dt = DateTime.parse(rawTime).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return rawTime;
    }
  }

  Future<void> _viewStory(Map<String, dynamic> story) async {
    final details = await _storyService.viewStory(storyId: story['story_ID']);
    final content = details['initialLeg'] as String? ?? 'No content.';
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(details['storyTitle'] as String? ?? 'Story Details'),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadStory(story, content: content);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadStory(Map<String, dynamic> story, {String? content}) async {
    final data = content ??
        (await _storyService.viewStory(storyId: story['story_ID']))['initialLeg'] as String;
    final bytes = utf8.encode(data);
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = 'story_${story['storyTitle']}.txt';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _deleteStory(Map<String, dynamic> story) async {
    await _storyService.deleteStory(storyId: story['story_ID']);
    _fetchSavedStories();
  }

  Future<void> _continueStory(Map<String, dynamic> story) async {
    final cont = await _storyService.continueStory(storyId: story['story_ID']);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          initialLeg: cont['storyLeg'] as String,
          options: List<String>.from(cont['options'] as List),
          storyTitle: cont['storyTitle'] as String,
        ),
      ),
    );
  }

  Widget _buildStoryItem(Map<String, dynamic> story) {
    final screen = MediaQuery.of(context).size;
    final isSmallScreen = screen.width < 1038 || screen.height < 925;
    final maxWidth = isSmallScreen ? screen.width * 0.9 : screen.width * 0.35;

    final title = story['storyTitle'] as String? ?? 'Untitled Story';
    final time = _formatTime(story['lastActivity'] as String? ?? 'Unknown');

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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                          icon: Icon(Icons.visibility, color: Colors.blue.shade700),
                          label: Text('View', style: TextStyle(color: Colors.blue.shade700)),
                          onPressed: () => _viewStory(story)),
                      TextButton.icon(
                          icon: Icon(Icons.download_rounded, color: Colors.blue.shade700),
                          label: Text('Download', style: TextStyle(color: Colors.blue.shade700)),
                          onPressed: () => _downloadStory(story)),
                      TextButton.icon(
                          icon: Icon(Icons.delete_outline, color: Colors.blue.shade700),
                          label: Text('Delete', style: TextStyle(color: Colors.blue.shade700)),
                          onPressed: () => _deleteStory(story)),
                      ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade300,
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          ),
                          icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
                          label: const Text('Continue', style: TextStyle(color: Colors.white)),
                          onPressed: () => _continueStory(story)),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 1038 || size.height < 925;

    // Image sizing
    const double largeImageWidth = 630;
    final double imgWidth = isSmallScreen ? size.width * 0.9 : largeImageWidth;
    final double imgHeight = imgWidth * 0.8;
    final double shadowBlur = isSmallScreen ? 0 : imgWidth * 0.03;
    final Offset shadowOffset = isSmallScreen
        ? Offset.zero
        : Offset(imgWidth * 0.02, imgHeight * 0.02);

    final Widget storyImage = Container(
      width: imgWidth,
      height: imgHeight,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: shadowBlur, offset: shadowOffset),
        ],
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

    // === Empty state: no stories loaded & not loading ===
    if (!_isLoading && _stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.orange.shade50,
        appBar: appBar,
        body: Center(
          child: Text(
            'You have no saved stories here yet',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: Colors.black12),
          ),
        ),
      );
    }

    // === Small-screen layout ===
    if (isSmallScreen) {
      return Scaffold(
        backgroundColor: Colors.orange.shade50,
        appBar: appBar,
        body: RefreshIndicator(
          onRefresh: _fetchSavedStories,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
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
        ),
      );
    }

    // === Large-screen layout ===
    final double imageTop = size.height * 0.18;
    final double cardsInset = imgHeight * 0.28;

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
              right: 24 + largeImageWidth * 0.1,
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
