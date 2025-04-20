import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'action_button.dart';

class FullStoryDialog extends StatefulWidget {
  final String fullStory;
  final List<String> dialogOptions;
  final ValueChanged<String> onOptionSelected;
  final VoidCallback onShowOptions;
  final bool canPick;

  const FullStoryDialog({
    Key? key,
    required this.fullStory,
    required this.dialogOptions,
    required this.onOptionSelected,
    required this.onShowOptions,
    required this.canPick,
  }) : super(key: key);

  @override
  State<FullStoryDialog> createState() => _FullStoryDialogState();
}

class _FullStoryDialogState extends State<FullStoryDialog> {
  final ScrollController _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ctrl.hasClients) _ctrl.jumpTo(_ctrl.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext dialogCtx) => AlertDialog(
    title: Text('Full Story So Far', style: GoogleFonts.atma()),
    content: Container(
      height: 300,
      width: double.maxFinite,
      child: Scrollbar(
        controller: _ctrl,
        child: SingleChildScrollView(
          controller: _ctrl,
          child: Text(widget.fullStory, style: GoogleFonts.atma()),
        ),
      ),
    ),
    actions: [
      if (widget.dialogOptions.isNotEmpty)
        ActionButton(
          label: 'Choose Next Action',
          onPressed: widget.canPick ? widget.onShowOptions : null,
        ),
      TextButton(
        onPressed: () => Navigator.pop(dialogCtx),
        child: Text('Close', style: GoogleFonts.atma()),
      ),
    ],
  );
}
