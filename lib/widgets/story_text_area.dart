import 'package:flutter/material.dart';

class StoryTextArea extends StatelessWidget {
  const StoryTextArea({
    super.key,
    required this.controller,
    required this.textController,
  });

  final ScrollController      controller;
  final TextEditingController textController;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color       : cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow   : [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Scrollbar(
        controller: controller,
        child: SingleChildScrollView(
          controller: controller,
          child: TextField(
            controller: textController,
            readOnly  : true,
            maxLines  : null,
            decoration: const InputDecoration.collapsed(
              hintText: 'Story will appear here…',
            ),
            style: tt.bodyLarge?.copyWith(height: 1.4),
          ),
        ),
      ),
    );
  }
}
