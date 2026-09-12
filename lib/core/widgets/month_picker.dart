import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/vistar.dart';

/// Picks a reporting month.
///
/// Everything in OpsApp is keyed by a `YYYY-MM` cycle, never by a day, so this
/// replaces `showDatePicker(initialDatePickerMode: year)` — which made you pick
/// a year, then a month, then an arbitrary day that was thrown away, and showed
/// a day grid that implied the day mattered.
///
/// Here a month is one tap: step the year, tap the month, done. Months outside
/// [firstMonth]..[lastMonth] are visible but disabled, so the boundary reads as
/// a limit rather than as missing data.
///
/// Returns the first day of the chosen month, or null if dismissed.
Future<DateTime?> showMonthPicker({
  required BuildContext context,
  required DateTime initial,
  DateTime? firstMonth,
  DateTime? lastMonth,
  String? helpText,
}) {
  final last = _monthOf(lastMonth ?? DateTime.now());
  final first = _monthOf(firstMonth ?? DateTime(last.year - 5, 1));
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _MonthPickerDialog(
      // A caller whose stored month drifted outside the range (a stale
      // selection, a clock roll) still opens on a valid page.
      initial: _clamp(_monthOf(initial), first, last),
      first: first,
      last: last,
      helpText: helpText ?? 'Select reporting month',
    ),
  );
}

DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

DateTime _clamp(DateTime v, DateTime lo, DateTime hi) {
  if (v.isBefore(lo)) return lo;
  if (v.isAfter(hi)) return hi;
  return v;
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({
    required this.initial,
    required this.first,
    required this.last,
    required this.helpText,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;
  final String helpText;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;

  bool get _canGoBack => _year > widget.first.year;
  bool get _canGoForward => _year < widget.last.year;

  bool _enabled(int month) {
    final m = DateTime(_year, month);
    return !m.isBefore(widget.first) && !m.isAfter(widget.last);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.helpText),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous year',
                  icon: const Icon(Icons.chevron_left),
                  onPressed:
                      _canGoBack ? () => setState(() => _year -= 1) : null,
                ),
                Expanded(
                  child: Text(
                    '$_year',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next year',
                  icon: const Icon(Icons.chevron_right),
                  onPressed:
                      _canGoForward ? () => setState(() => _year += 1) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.1,
              children: [
                for (int m = 1; m <= 12; m++)
                  _MonthCell(
                    label: DateFormat.MMM().format(DateTime(_year, m)),
                    selected:
                        _year == widget.initial.year && m == widget.initial.month,
                    enabled: _enabled(m),
                    onTap: () => Navigator.of(context).pop(DateTime(_year, m)),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = !enabled
        ? theme.disabledColor
        : selected
            ? Colors.white
            : theme.colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(Vistar.rSm),
        child: Ink(
          decoration: BoxDecoration(
            // The selected month wears the ribbon; the rest stay quiet so the
            // current choice is obvious at a glance.
            gradient: selected && enabled ? Vistar.ribbon : null,
            color: selected && enabled
                ? null
                : theme.colorScheme.surfaceContainerHigh
                    .withValues(alpha: enabled ? 1 : 0.4),
            borderRadius: BorderRadius.circular(Vistar.rSm),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
