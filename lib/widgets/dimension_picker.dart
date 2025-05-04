// lib/widgets/dimension_picker.dart
//
// Renders all story‑dimension pickers.
// • Scales down to 240 × 340 px.
// • Handles one‑level and two‑level (nested) dimensions.
// • When [readOnlyJoiner] is true every dropdown is disabled so
//   joiners can view—but not change—the host’s choices.

import 'package:flutter/material.dart';
import 'info_banner.dart';

typedef OnDimChanged    = void Function(String dimKey, String? newVal);
typedef OnExpandChanged = void Function(String groupKey, bool expanded);

const String _kInfoMsg =
    'Pick only the options you care about — anything left unselected '
    'will be RANDOM!\n\n'
    '⚠️  Some dimensions are two‑step: first pick a category, then an option form the new list.';

class DimensionPicker extends StatefulWidget {
  final Map<String, dynamic> groups;      // grouped dimension map
  final Map<String, String?> choices;     // currently‑selected leaves
  final Map<String, bool>    expanded;    // which group cards are open
  final OnDimChanged         onDimChanged;
  final OnExpandChanged      onExpandChanged;
  final bool                 readOnlyJoiner;

  const DimensionPicker({
    super.key,
    required this.groups,
    required this.choices,
    required this.expanded,
    required this.onDimChanged,
    required this.onExpandChanged,
    this.readOnlyJoiner = false,
  });

  @override
  State<DimensionPicker> createState() => _DimensionPickerState();
}

/* ────────────────────────────────────────────────────────── */

class _DimensionPickerState extends State<DimensionPicker> {
  /// Tracks the user’s pick in each *parent* dropdown of a nested map.
  final Map<String, String?> _parentSelections = {};

  @override
  Widget build(BuildContext context) {
    final width   = MediaQuery.of(context).size.width;
    final narrow  = width < 320;                       // watch‑sized screens
    final tt      = Theme.of(context).textTheme;
    final scheme  = Theme.of(context).colorScheme;

    /* ── top banner ─────────────────────────────────────────── */
    final List<Widget> widgets = [
      const InfoBanner(message: _kInfoMsg),
      const SizedBox(height: 12),
    ];

    /* ── build one card per dimension group ────────────────── */
    widget.groups.forEach((groupKey, groupVal) {
      final Map<String, dynamic> dimsRaw = {};
      if (groupVal is Map<String, dynamic>) {
        dimsRaw.addAll(groupVal);
      } else {
        dimsRaw[groupKey] = groupVal;
      }

      widgets.add(
        Padding(
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
              onExpansionChanged: (o) =>
                  widget.onExpandChanged(groupKey, o),
              children: dimsRaw.entries.map((dimEntry) {
                final dimKey = dimEntry.key;
                final rawVal = dimEntry.value;

                /* ── NESTED MAP → two dropdowns ─────────────── */
                if (rawVal is Map<String, dynamic>) {
                  // Determine current parent pick
                  String? parentPick = _parentSelections[dimKey];
                  parentPick ??= rawVal.keys.firstWhere(
                        (k) => widget.choices.containsKey(k),
                    orElse: () => '',
                  );
                  if (parentPick.isEmpty) parentPick = null;

                  final childOptions = parentPick != null
                      ? _asStrings(rawVal[parentPick])
                      : const <String>[];

                  final childPick = parentPick != null
                      ? widget.choices[parentPick]
                      : null;

                  Widget parentDropdown = DropdownButton<String>(
                    isExpanded: true,
                    value     : parentPick,
                    hint      : _paddedText(dimKey, tt, narrow),
                    items: rawVal.keys
                        .map((k) => DropdownMenuItem<String>(
                      value: k,
                      child: _paddedText(k, tt, narrow),
                    ))
                        .toList(),
                    onChanged: widget.readOnlyJoiner
                        ? null
                        : (v) => setState(() {
                      _parentSelections[dimKey] = v;
                      if (v != null) widget.onDimChanged(v, null);
                    }),
                  );

                  Widget tooltip = Tooltip(
                    message:
                    'Pick a category first; a second list of options appears.',
                    preferBelow: false,
                    child: Icon(Icons.help_outline,
                        size : narrow ? 16 : 20,
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
                            hint      : _paddedText(
                                'Select $parentPick', tt, narrow),
                            items: childOptions
                                .map((v) => DropdownMenuItem<String>(
                              value: v,
                              child: _paddedText(v, tt, narrow),
                            ))
                                .toList(),
                            onChanged: widget.readOnlyJoiner
                                ? null
                                : (v) =>
                                widget.onDimChanged(parentPick!, v),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                /* ── SINGLE‑LEVEL dimension ─────────────────── */
                final options = _asStrings(rawVal);

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: DropdownButton<String>(
                    isExpanded   : true,
                    value        : widget.choices[dimKey],
                    itemHeight   : null,
                    menuMaxHeight: 400,
                    hint         : _paddedText(dimKey, tt, narrow),
                    items: options
                        .map((v) => DropdownMenuItem<String>(
                      value: v,
                      child: _paddedText(v, tt, narrow),
                    ))
                        .toList(),
                    onChanged: widget.readOnlyJoiner
                        ? null
                        : (v) => widget.onDimChanged(dimKey, v),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
    });

    return Column(children: widgets);
  }

  /* ── helpers ─────────────────────────────────────────────── */

  List<String> _asStrings(dynamic v) =>
      v is Iterable ? v.map((e) => e.toString()).toList() : [v.toString()];

  Padding _paddedText(String txt, TextTheme tt, bool narrow) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      txt,
      style   : tt.bodyMedium?.copyWith(fontSize: narrow ? 12 : null),
      softWrap: true,
      overflow: TextOverflow.visible,
    ),
  );
}
