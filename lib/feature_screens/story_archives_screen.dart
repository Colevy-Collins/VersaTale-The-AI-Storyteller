// lib/screens/story_archives_screen.dart
// -----------------------------------------------------------------------------
// Lists saved stories and lets the user  View ▸ Download ▸ Delete ▸ Continue.
// Dialogs scale smoothly from tiny wear‑OS screens (240 × 340) up to desktop.
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:html' as html;                      // download helper (web‑only)
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/story_service.dart';
import 'story_screen.dart';

class StoryArchivesScreen extends StatefulWidget {
  const StoryArchivesScreen({super.key});

  @override
  State<StoryArchivesScreen> createState() => _StoryArchivesScreenState();
}

/*──────────────────────── controller ────────────────────────*/

class _StoryArchivesScreenState extends State<StoryArchivesScreen> {
  final StoryService _storyService = StoryService();

  List<Map<String, dynamic>> _savedStories = const [];
  bool   _isLoading      = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refreshStories();
  }

  Future<void> _refreshStories() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _storyService.getSavedStories();
      _savedStories = List<Map<String, dynamic>>.from(fetched);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String rawIso) {
    try {
      final dt = DateTime.parse(rawIso).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return rawIso;
    }
  }

  /*───────────────────── actions / navigation ─────────────────────*/

  Future<void> _showViewDialog(Map story) async {
    final storyData   = await _storyService.viewStory(storyId: story['story_ID']);
    final storyText   = storyData['initialLeg'] ?? 'No content.';
    final storyTitle  = storyData['storyTitle'] ?? 'Story Details';
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) {
        final Size screen = MediaQuery.of(ctx).size;

        // Clamp dialog dimensions: • min fits 240×340   • max stays desktop‑friendly
        const double kMaxDialogWidth  = 560;
        const double kMaxDialogHeight = 600;
        final double dialogWidth  = screen.width  < kMaxDialogWidth
            ? screen.width  * 0.95
            : kMaxDialogWidth;
        final double dialogHeight = screen.height < kMaxDialogHeight
            ? screen.height * 0.85
            : kMaxDialogHeight;

        return Dialog(
          insetPadding: EdgeInsets.zero,           // let our own constraints rule
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth : dialogWidth,
              maxHeight: dialogHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── title ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                  child: Text(
                    storyTitle,
                    style    : Theme.of(ctx).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
                const Divider(height: 1),
                // ── scrollable body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Text(storyText),
                  ),
                ),
                const Divider(height: 1),
                // ── buttons ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _downloadStory(story, content: storyText);
                        },
                        child: const Text('Download'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadStory(Map story, {String? content}) async {
    if (!kIsWeb) return;                          // mobile / desktop: no‑op

    final data  = content ??
        (await _storyService.viewStory(storyId: story['story_ID']))['initialLeg'];
    final bytes = utf8.encode(data);
    final blob  = html.Blob([bytes], 'text/plain');
    final url   = html.Url.createObjectUrlFromBlob(blob);

    final a = html.document.createElement('a') as html.AnchorElement
      ..href     = url
      ..download = 'story_${story['storyTitle']}.txt';
    html.document.body?.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _deleteStory(Map story) async {
    await _storyService.deleteStory(storyId: story['story_ID']);
    _refreshStories();
  }

  Future<void> _continueStory(Map story) async {
    final continuation = await _storyService.continueStory(
        storyId: story['story_ID']);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          initialLeg       : continuation['storyLeg'],
          options          : List<String>.from(continuation['options'] ?? []),
          storyTitle       : continuation['storyTitle'],
          inputTokens      : continuation['inputTokens']     ?? 0,
          outputTokens     : continuation['outputTokens']    ?? 0,
          estimatedCostUsd : continuation['estimatedCostUsd']?? 0.0,
        ),
      ),
    );
  }

  /*───────────────────── UI helpers ─────────────────────────────*/

  Widget _buildTextButton(
      {required IconData icon,
        required String  label,
        required VoidCallback onPressed}) {
    return TextButton.icon(
      icon : Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }

  Widget _buildStoryCard(Map story) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextTheme   tt = Theme.of(context).textTheme;

    final String  title          = story['storyTitle']   ?? 'Untitled';
    final String  lastModified   = _formatDate(story['lastActivity'] ?? '');
    final int     inputTokens    = story['inputTokens']  ?? 0;
    final int     outputTokens   = story['outputTokens'] ?? 0;
    final double  estimatedCost  = (story['estimatedCostUsd'] ?? 0.0) as double;

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.primaryContainer],
            begin : Alignment.topLeft,
            end   : Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(lastModified, style: tt.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 4),
            Text('$inputTokens / $outputTokens tok • \$${estimatedCost.toStringAsFixed(4)}',
                style: tt.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildTextButton(
                  icon: Icons.visibility,
                  label: 'View',
                  onPressed: () => _showViewDialog(story),
                ),
                _buildTextButton(
                  icon: Icons.download_rounded,
                  label: 'Download',
                  onPressed: () => _downloadStory(story),
                ),
                _buildTextButton(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  onPressed: () => _deleteStory(story),
                ),
                ElevatedButton.icon(
                  icon : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Continue'),
                  onPressed: () => _continueStory(story),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /*──────────────────────── build ─────────────────────────*/

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs  = Theme.of(context).colorScheme;
    final TextTheme   tt  = Theme.of(context).textTheme;
    final Image       heroImage = Image.asset('assets/reading2.png',
        fit: BoxFit.contain);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(
          backgroundColor: cs.primary,
          title  : Text('Saved Stories', style: tt.titleLarge),
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: _isLoading && _savedStories.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(child: Text(_errorMessage!, style: tt.bodyLarge))
            : _savedStories.isEmpty
            ? Center(
          child: Text(
            'You have no saved stories yet',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.outline,
            ),
          ),
        )
            : RefreshIndicator(
          onRefresh: _refreshStories,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              final bool isSmallScreen =
                  constraints.maxWidth < 1000 ||
                      constraints.maxHeight < 900;

              // list of cards
              final Widget cardList = ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _savedStories.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 14),
                itemBuilder: (_, i) =>
                    _buildStoryCard(_savedStories[i]),
              );

              if (isSmallScreen) {
                // cards first, image underneath
                return SingleChildScrollView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      cardList,
                      const SizedBox(height: 24),
                      heroImage,
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }

              // large‑screen layout – cards left, image right
              return Stack(
                children: [
                  Positioned(
                    top  : constraints.maxHeight * 0.18,
                    right: 24,
                    child: SizedBox(
                      width : 630,
                      height: 630 * 0.8,
                      child : heroImage,
                    ),
                  ),
                  Padding(
                    padding:
                    const EdgeInsets.only(right: 300),
                    child: cardList,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
