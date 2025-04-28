// lib/widgets/dimension_picker.dart

import 'package:flutter/material.dart';

typedef OnDimChanged    = void Function(String dimKey, String? newVal);
typedef OnExpandChanged = void Function(String groupKey, bool expanded);

class DimensionPicker extends StatelessWidget {
  final Map<String, dynamic> groups;
  final Map<String, String?> choices;
  final Map<String, bool> expanded;
  final OnDimChanged onChanged;
  final OnExpandChanged onExpand;

  const DimensionPicker({
    super.key,
    required this.groups,
    required this.choices,
    required this.expanded,
    required this.onChanged,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    /* ── high-visibility banner ────────────────────────────────────── */
    final widgets = <Widget>[
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline,
                color: scheme.onSecondaryContainer, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pick only the options you care about — anything left '
                    'unselected will be RANDOMLY chosen!',
                style: tt.bodyLarge?.copyWith(
                  fontSize : 16,
                  fontWeight: FontWeight.w700,
                  color     : scheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
    ];

    /* ── each dimension group ─────────────────────────────────────── */
    widgets.addAll(groups.entries.map((group) {
      final groupKey = group.key;

      // normalise to Map<String, List<String>>
      final dims = <String, List<String>>{};
      final raw  = group.value;
      void _addDim(String k, dynamic v) {
        if (v == null) return;
        if (v is Iterable) {
          dims[k] = v.map((e) => e.toString()).toList();
        } else if (v is Map) {
          dims[k] = v.keys.map((e) => e.toString()).toList();
        } else {
          dims[k] = [v.toString()];
        }
      }
      if (raw is Map) raw.forEach((k, v) => _addDim(k.toString(), v));
      else _addDim(groupKey, raw);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Card(
          child: ExpansionTile(
            title: Text(groupKey,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            initiallyExpanded: expanded[groupKey] ?? false,
            onExpansionChanged: (o) => onExpand(groupKey, o),
            children: dims.entries.map((dim) {
              return Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value     : choices[dim.key],
                    itemHeight: null,                 // ←■■ key fix
                    menuMaxHeight: 400,               // optional scroll cap
                    hint: _paddedText(dim.key, tt),
                    items: dim.value.map((v) => DropdownMenuItem<String>(
                      value: v,
                      child: _paddedText(v, tt),
                    ))
                        .toList(),
                    onChanged: (v) => onChanged(dim.key, v),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }));

    return Column(children: widgets);
  }

  /// Reusable padded, wrap-enabled text widget
  Padding _paddedText(String txt, TextTheme tt) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      txt,
      style   : tt.bodyMedium,
      softWrap: true,
      overflow: TextOverflow.visible,
    ),
  );
}
