import 'package:flutter/material.dart';
import 'dart:math';

class DimensionDropdown extends StatefulWidget {
  final String label;                 // e.g. "Dimension 2 - Genre"
  final List<String> options;        // the list of possible choices
  final String? initialValue;        // currently-selected value, if any
  final ValueChanged<String?> onChanged;

  const DimensionDropdown({
    Key? key,
    required this.label,
    required this.options,
    this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  _DimensionDropdownState createState() => _DimensionDropdownState();
}

class _DimensionDropdownState extends State<DimensionDropdown> {
  String? _selectedValue;

  @override
  void initState() {
    super.initState();
    // If there's an initial value, use it; otherwise default to null.
    _selectedValue = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    // Combine the original list with a "Random" entry.
    // You can insert "Random" at the start or end, whichever you prefer.
    final allOptions = [...widget.options];
    allOptions.insert(0, "Random");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
        DropdownButton<String>(
          value: _selectedValue,
          hint: Text("Select ${widget.label}"),
          isExpanded: true,
          items: allOptions.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedValue = val;
            });
            widget.onChanged(val);
          },
        ),
      ],
    );
  }
}
