// lib/widgets/dimension_picker.dart
// -----------------------------------------------------------------------------
// A reusable widget to pick dimensions or vote on them.
// Handles both Map of options and plain List of options gracefully.
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

typedef OnDimChanged = void Function(String dimensionKey, String? newValue);
typedef OnExpandChanged = void Function(String groupKey, bool isExpanded);

class DimensionPicker extends StatelessWidget {
  final Map<String, dynamic> groups;
  final Map<String, String?> choices;
  final Map<String, bool> expanded;
  final OnDimChanged onChanged;
  final OnExpandChanged onExpand;

  const DimensionPicker({
    Key? key,
    required this.groups,
    required this.choices,
    required this.expanded,
    required this.onChanged,
    required this.onExpand,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: groups.entries.map((entry) {
        final groupKey = entry.key;
        final raw = entry.value;

        // Normalize raw into a Map<String, List<String>>
        final Map<String, List<String>> dims = {};
        if (raw is Map) {
          raw.forEach((k, v) {
            if (v is List<String>) {
              dims[k.toString()] = v;
            } else if (v is Iterable) {
              dims[k.toString()] = v.map((e) => e.toString()).toList();
            }
          });
        } else if (raw is Iterable) {
          // Single list under groupKey
          dims[groupKey] = raw.map((e) => e.toString()).toList();
        }

        if (dims.isEmpty) return SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ExpansionTile(
              key: PageStorageKey(groupKey),
              title: Text(groupKey, style: GoogleFonts.atma(fontWeight: FontWeight.bold)),
              initiallyExpanded: expanded[groupKey] ?? false,
              onExpansionChanged: (open) => onExpand(groupKey, open),
              children: dims.entries.map((dimEntry) {
                final dimKey = dimEntry.key;
                final options = dimEntry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: DropdownButton<String>(
                    value: choices[dimKey],
                    isExpanded: true,
                    hint: Text(dimKey),
                    items: options.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                    onChanged: (v) => onChanged(dimKey, v),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    );
  }
}
