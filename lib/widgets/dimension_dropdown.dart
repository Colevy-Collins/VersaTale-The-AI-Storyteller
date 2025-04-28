import 'package:flutter/material.dart';

class DimensionDropdown extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? initialValue;
  final ValueChanged<String?> onChanged;

  const DimensionDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: tt.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: cs.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButton<String>(
            value: initialValue,
            isExpanded: true,
            underline: const SizedBox(),
            items: options
                .map(
                  (o) => DropdownMenuItem(
                value: o,
                child: Text(o, style: tt.bodyMedium),
              ),
            )
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
