import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DimensionDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final TextStyle? textStyle;

  const DimensionDropdown({
    Key? key,
    required this.label,
    required this.options,
    required this.initialValue,
    required this.onChanged,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build dropdown items: each option wrapped in a Container that expands in height as needed.
    List<DropdownMenuItem<String>> items = options.map((option) {
      return DropdownMenuItem<String>(
        value: option,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            option,
            style: textStyle ?? GoogleFonts.kottaOne(),
            softWrap: true,
          ),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label for the dropdown
        Text(
          label,
          style: (textStyle ?? GoogleFonts.kottaOne()).copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Dropdown field wrapped in a Container with its own border and padding.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: initialValue,
            isExpanded: true,
            itemHeight: null, // Allows items to expand in height as needed.
            underline: const SizedBox(), // Remove default underline.
            items: items,
            onChanged: onChanged,
            style: textStyle ?? GoogleFonts.kottaOne(),
          ),
        ),
      ],
    );
  }
}
