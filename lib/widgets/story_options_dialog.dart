import 'package:flutter/material.dart';
import '../utils/ui_utils.dart';

class StoryOptionsDialog extends StatefulWidget {
  const StoryOptionsDialog({
    super.key,
    required this.onStartStory,
    required this.onContinueStory,
  });

  final void Function(bool group) onStartStory;
  final void Function(bool group) onContinueStory;

  @override
  State<StoryOptionsDialog> createState() => _StoryOptionsDialogState();
}

class _StoryOptionsDialogState extends State<StoryOptionsDialog> {
  bool _group = false;                // false → solo, true → group
  late final ScrollController _sc;    // shared by Scrollbar + ScrollView

  @override
  void initState() {
    super.initState();
    _sc = ScrollController();
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /* ─── tiny‑screen helpers ─── */
    final tinyPortrait  = isTinyScreen(context) && !isTinyLandscape(context);
    final tinyLandscape = isTinyLandscape(context);
    final isTiny        = tinyPortrait || tinyLandscape;

    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    TextStyle? _lbl(double size) =>
        tt.labelLarge?.copyWith(fontSize: isTiny ? size : null);

    /* ─── Solo / Group radio tiles ─── */
    Widget _choice(String title, bool val) => ListTile(
      dense: tinyLandscape,
      visualDensity: tinyLandscape
          ? const VisualDensity(horizontal: -2, vertical: -2)
          : null,
      title: Text(title,
          style: tt.bodyLarge?.copyWith(fontSize: isTiny ? 14 : null)),
      leading: Radio<bool>(
        value: val,
        groupValue: _group,
        onChanged: (v) => setState(() => _group = v ?? false),
      ),
    );

    /* ─── Buttons ─── */
    ElevatedButton _btn(
        String text, VoidCallback tap, Color bg, Color fg) =>
        ElevatedButton(
          onPressed: tap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            minimumSize:
            isTiny ? const Size.fromHeight(40) : const Size.fromHeight(48),
          ),
          child:
          Text(text, textAlign: TextAlign.center, style: _lbl(12), softWrap: true),
        );

    final cancelBtn   =
    TextButton(onPressed: Navigator.of(context).pop, child: Text('Cancel', style: _lbl(12)));
    final startBtn    = _btn('Start Story',    () => widget.onStartStory(_group),  cs.primary,   cs.onPrimary);
    final continueBtn = _btn('Continue Story', () => widget.onContinueStory(_group), cs.secondary, cs.onSecondary);

    /* ─── ACTIONS layout list ─── */
    late final List<Widget> actions;
    if (tinyPortrait) {
      // vertical stack
      actions = [
        cancelBtn,
        const SizedBox(height: 8),
        startBtn,
        const SizedBox(height: 8),
        continueBtn,
      ];
    } else if (tinyLandscape) {
      // two‑row stack
      actions = [
        Row(children: [Expanded(child: startBtn), const SizedBox(width: 8), Expanded(child: continueBtn)]),
        const SizedBox(height: 8),
        cancelBtn,
      ];
    } else {
      // normal / large screens → give OverflowBar *only buttons*
      actions = [cancelBtn, startBtn, continueBtn];
    }

    /* ─── Scrollable body (shared controller) ─── */
    final scrollBody = SingleChildScrollView(
      controller: _sc,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _choice('Solo Story',  false),
          _choice('Group Story', true),
        ],
      ),
    );

    final dialogContent = isTiny
        ? Scrollbar(
      controller: _sc,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      radius: const Radius.circular(4),
      child: scrollBody,
    )
        : scrollBody;

    /* ─── BUILD ─── */
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      title: Text('Story Options',
          style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      content: dialogContent,
      // On large screens, spread buttons so Cancel is left, others right
      actionsAlignment: tinyPortrait
          ? MainAxisAlignment.center
          : (tinyLandscape ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween),
      actionsPadding: isTiny
          ? const EdgeInsets.symmetric(horizontal: 0, vertical: 8)
          : const EdgeInsets.fromLTRB(8, 8, 8, 12),
      actions: isTiny ? [Column(children: actions)] : actions,
    );
  }
}
