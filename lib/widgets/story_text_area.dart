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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          child: TextField(
            controller: textController,
            maxLines: null,
            readOnly: true,
            decoration:
            const InputDecoration.collapsed(hintText: 'Story will appear here…'),
            style: GoogleFonts.atma(),
          ),
        ),
      ),
    );
  }
}
