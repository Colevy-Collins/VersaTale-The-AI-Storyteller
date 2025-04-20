// lib/widgets/story_text_area.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StoryTextArea extends StatelessWidget {
  final ScrollController controller;
  final TextEditingController textController;

  const StoryTextArea({
    Key? key,
    required this.controller,
    required this.textController,
  }) : super(key: key);

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xF0EDE8), // updated background color
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          child: TextField(
            controller: textController,
            maxLines: null,
            readOnly: true,
            decoration: const InputDecoration.collapsed(
              hintText: 'Story will appear here…',
            ),
            style: GoogleFonts.kottaOne(
              fontSize: 18,
              height: 1.4,
              color: const Color(0xFF212121),
            ),
          ),
        ),
      ),
    );
  }
}
