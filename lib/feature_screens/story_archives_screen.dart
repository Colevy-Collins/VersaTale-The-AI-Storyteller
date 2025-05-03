// lib/screens/story_archives_screen.dart
// -----------------------------------------------------------------------------
// Lists saved stories and lets the user  View ▸ Download ▸ Delete ▸ Continue.
// Adapts to any ColorScheme; safe on web / desktop / mobile.
// -----------------------------------------------------------------------------

import 'dart:convert';
import 'dart:html' as html;                       // download helper (web‑only)
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
  final _svc = StoryService();

  List<Map<String, dynamic>> _stories = const [];
  bool   _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final fetched = await _svc.getSavedStories();
      _stories = List<Map<String, dynamic>>.from(fetched);
      _error   = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmt(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat.yMMMd().add_jm().format(dt);
    } catch (_) {
      return raw;
    }
  }

  /*──────────────────────── actions ─────────────────────────*/

  Future<void> _view(Map s) async {
    final d   = await _svc.viewStory(storyId: s['story_ID']);
    final txt = d['initialLeg'] ?? 'No content.';
    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title  : Text(d['storyTitle'] ?? 'Story Details'),
        content: SingleChildScrollView(child: Text(txt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _download(s, content: txt);
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _download(Map s, {String? content}) async {
    if (!kIsWeb) return;                             // mobile / desktop: no‑op

    final data  = content ??
        (await _svc.viewStory(storyId: s['story_ID']))['initialLeg'];
    final bytes = utf8.encode(data);
    final blob  = html.Blob([bytes], 'text/plain');
    final url   = html.Url.createObjectUrlFromBlob(blob);

    final a = html.document.createElement('a') as html.AnchorElement
      ..href = url
      ..download = 'story_${s['storyTitle']}.txt';
    html.document.body?.append(a);
    a.click();
    a.remove();
    html.Url.revokeObjectUrl(url);
  }

  Future<void> _delete(Map s) async {
    await _svc.deleteStory(storyId: s['story_ID']);
    _refresh();
  }

  Future<void> _cont(Map s) async {
    final c = await _svc.continueStory(storyId: s['story_ID']);
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StoryScreen(
          initialLeg       : c['storyLeg'],
          options          : List<String>.from(c['options'] ?? []),
          storyTitle       : c['storyTitle'],
          inputTokens      : c['inputTokens']     ?? 0,
          outputTokens     : c['outputTokens']    ?? 0,
          estimatedCostUsd : c['estimatedCostUsd']?? 0.0,
        ),
      ),
    );
  }

  /*──────────────────────── helpers ────────────────────────*/

  Widget _textBtn(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      icon : Icon(icon),
      label: Text(label),
      onPressed: onTap,
    );
  }

  Widget _card(Map s) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = s['storyTitle'] ?? 'Untitled';
    final time  = _fmt(s['lastActivity'] ?? '');
    final inTok = s['inputTokens'] ?? 0;
    final outTok= s['outputTokens'] ?? 0;
    final cost  = (s['estimatedCostUsd'] ?? 0.0) as double;

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
            Text(time, style: tt.bodySmall?.copyWith(color: cs.outline)),
            const SizedBox(height: 4),
            Text('$inTok / $outTok tok • \$${cost.toStringAsFixed(4)}',
                style: tt.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _textBtn(Icons.visibility,        'View',     () => _view(s)),
                _textBtn(Icons.download_rounded, 'Download', () => _download(s)),
                _textBtn(Icons.delete_outline,    'Delete',   () => _delete(s)),
                ElevatedButton.icon(
                  icon : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Continue'),
                  onPressed: () => _cont(s),
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
    final cs  = Theme.of(context).colorScheme;
    final tt  = Theme.of(context).textTheme;
    final img = Image.asset('assets/reading2.png', fit: BoxFit.contain);

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        backgroundColor: cs.background,
        appBar: AppBar(
          backgroundColor: cs.primary,
          title: Text('Saved Stories', style: tt.titleLarge),
          leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        ),
        body: _loading && _stories.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!, style: tt.bodyLarge))
            : _stories.isEmpty
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
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (ctx, c) {
              final small =
                  c.maxWidth < 1000 || c.maxHeight < 900;

              // list of cards
              final list = ListView.separated(
                shrinkWrap: true,
                physics:
                const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _stories.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 14),
                itemBuilder: (_, i) => _card(_stories[i]),
              );

              if (small) {
                // cards first, image underneath
                return SingleChildScrollView(
                  physics:
                  const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      list,
                      const SizedBox(height: 24),
                      img,
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }

              // large‑screen layout – cards left, image right
              return Stack(
                children: [
                  Positioned(
                    top  : c.maxHeight * 0.18,
                    right: 24,
                    child: SizedBox(
                      width : 630,
                      height: 630 * 0.8,
                      child : img,
                    ),
                  ),
                  Padding(
                    padding:
                    const EdgeInsets.only(right: 300),
                    child: list,
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
