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
  Widget build(BuildContext dialogCtx) => Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.brown.shade300, width: 2),
    ),
    backgroundColor: Colors.brown.shade50.withOpacity(0.9),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Current Story',
            style: GoogleFonts.kottaOne(
              fontSize: 24,
              color: Colors.brown.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.brown.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Scrollbar(
              controller: _ctrl,
              child: SingleChildScrollView(
                controller: _ctrl,
                padding: const EdgeInsets.all(8),
                child: Text(
                  widget.fullStory,
                  style: GoogleFonts.kottaOne(color: Colors.brown.shade800),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.dialogOptions.isNotEmpty)
            ActionButton(
              label: 'Choose Next Action',
              onPressed: widget.canPick ? widget.onShowOptions : null,
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              'Close',
              style: GoogleFonts.kottaOne(
                color: Colors.brown.shade800,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
