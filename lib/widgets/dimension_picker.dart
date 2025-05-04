// lib/widgets/dimension_picker.dart
import 'package:flutter/material.dart';

typedef OnDimChanged    = void Function(String dimKey, String? newVal);
typedef OnExpandChanged = void Function(String groupKey, bool expanded);

class DimensionPicker extends StatefulWidget {
  final Map<String, dynamic> groups;
  final Map<String, String?> choices;     // leaf‑only map
  final Map<String, bool>    expanded;
  final OnDimChanged         onChanged;
  final OnExpandChanged      onExpand;

  const DimensionPicker({
    super.key,
    required this.groups,
    required this.choices,
    required this.expanded,
    required this.onChanged,
    required this.onExpand,
  });

  @override
  State<DimensionPicker> createState() => _DimensionPickerState();
}

/* ─────────────────────────────────────────────────────────────── */

class _DimensionPickerState extends State<DimensionPicker> {
  /// Tracks the user’s pick in each *parent* dropdown of a nested map.
  final Map<String, String?> _parentSelections = {};

  @override
  Widget build(BuildContext context) {
    final width  = MediaQuery.of(context).size.width;
    final narrow = width < 320;                       // watch‑sized screens
    final tt     = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    /* ── top banner ───────────────────────────────────────────── */
    final widgets = <Widget>[
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment:
          narrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                color: scheme.onSecondaryContainer,
                size: narrow ? 20 : 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                narrow
                    ? 'Unpicked options are random. Some options have two-step selection: pick a group, then pick an option.'
                    : 'Pick only the options you care about — anything left '
                    'unselected will be RANDOMLY chosen!\n\n'
                    '⚠️  Some dimensions have extra levels. Choose a '
                    'category first; a second list will appear.',
                style: tt.bodyMedium?.copyWith(
                  fontSize : narrow ? 12 : 16,
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

    /* ── each dimension group ─────────────────────────────────── */
    widgets.addAll(widget.groups.entries.map((groupEntry) {
      final groupKey = groupEntry.key;
      final rawValue = groupEntry.value;

      // flatten group to map<dimKey, rawVal>
      final dimsRaw = <String, dynamic>{};
      if (rawValue is Map<String, dynamic>) {
        dimsRaw.addAll(rawValue);
      } else {
        dimsRaw[groupKey] = rawValue;
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Card(
          child: ExpansionTile(
            title: Text(
              groupKey,
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize  : narrow ? 14 : null,
              ),
            ),
            initiallyExpanded: widget.expanded[groupKey] ?? false,
            onExpansionChanged: (o) => widget.onExpand(groupKey, o),
            children: dimsRaw.entries.map((dimEntry) {
              final dimKey = dimEntry.key;
              final value  = dimEntry.value;

              /* ── nested map → two dropdowns ───────────────── */
              if (value is Map<String, dynamic>) {
                final parentPick = _parentSelections[dimKey];
                final nestedMap  = value;

                final childOptions = parentPick != null
                    ? _asStrings(nestedMap[parentPick])
                    : const <String>[];

                final childPick = parentPick != null
                    ? widget.choices[parentPick]          // leaf key == parentPick
                    : null;

                Widget parentDropdown = DropdownButton<String>(
                  isExpanded: true,
                  value     : parentPick,
                  hint      : _padText(dimKey, tt, narrow),
                  items: nestedMap.keys
                      .map((k) => DropdownMenuItem<String>(
                    value: k,
                    child: _padText(k, tt, narrow),
                  ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _parentSelections[dimKey] = v;
                    widget.onChanged(v!, null);   // clear any previous leaf pick
                  }),
                );

                // For very narrow screens stack tooltip below to avoid overflow
                Widget tooltip = Tooltip(
                  message:
                  'Pick a category first; a second list of options appears.',
                  preferBelow: false,
                  child: Icon(Icons.help_outline,
                      size: narrow ? 16 : 20,
                      color: scheme.onSurfaceVariant),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      narrow
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          parentDropdown,
                          const SizedBox(height: 4),
                          tooltip,
                        ],
                      )
                          : Row(
                        children: [
                          Expanded(child: parentDropdown),
                          const SizedBox(width: 4),
                          tooltip,
                        ],
                      ),
                      if (parentPick != null) ...[
                        const SizedBox(height: 12),
                        DropdownButton<String>(
                          isExpanded: true,
                          value     : childPick,
                          hint      : _padText('Select $parentPick', tt, narrow),
                          items: childOptions
                              .map((v) => DropdownMenuItem<String>(
                            value: v,
                            child: _padText(v, tt, narrow),
                          ))
                              .toList(),
                          onChanged: (v) =>
                              widget.onChanged(parentPick, v),
                        ),
                      ],
                    ],
                  ),
                );
              }

              /* ── single dropdown (one‑level dimension) ─────── */
              final options = _asStrings(value);

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                child: DropdownButton<String>(
                  isExpanded   : true,
                  value        : widget.choices[dimKey],
                  itemHeight   : null,
                  menuMaxHeight: 400,
                  hint         : _padText(dimKey, tt, narrow),
                  items: options
                      .map((v) => DropdownMenuItem<String>(
                    value: v,
                    child: _padText(v, tt, narrow),
                  ))
                      .toList(),
                  onChanged: (v) => widget.onChanged(dimKey, v),
                ),
              );
            }).toList(),
          ),
        ),
      );
    }));

    return Column(children: widgets);
  }

  /* ── helpers ─────────────────────────────────────────────── */

  List<String> _asStrings(dynamic v) =>
      v is Iterable ? v.map((e) => e.toString()).toList() : [v.toString()];

  Padding _padText(String txt, TextTheme tt, bool narrow) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      txt,
      style   : tt.bodyMedium?.copyWith(fontSize: narrow ? 12 : null),
      softWrap: true,
      overflow: TextOverflow.visible,
    ),
  );
}
