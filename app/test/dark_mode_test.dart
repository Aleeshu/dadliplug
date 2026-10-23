import 'package:antigua_business_map/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Selected chips (opening days, category filters, plan choices) are filled
/// with the ink colour. In dark mode ink is near-white, and the label used
/// to be ink as well: white on white, as seen on a phone 2026-10-23.
void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    test('$name: a selected chip label contrasts with its fill', () {
      final chips = theme.chipTheme;
      final selected = WidgetStateProperty.resolveAs(chips.labelStyle, {
        WidgetState.selected,
      })!;
      final plain = WidgetStateProperty.resolveAs(
        chips.labelStyle,
        <WidgetState>{},
      )!;
      expect(selected.color, isNot(chips.selectedColor));
      expect(plain.color, isNot(chips.backgroundColor));
      expect(selected.color, isNot(plain.color));
    });
  }

  testWidgets(
    'dark: a selected FilterChip draws its label in the light-on-dark '
    'flip',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: FilterChip(
              label: const Text('Mon'),
              selected: true,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      final label = tester.widget<DefaultTextStyle>(
        find
            .ancestor(
              of: find.text('Mon'),
              matching: find.byType(DefaultTextStyle),
            )
            .first,
      );
      expect(label.style.color, isNot(AppTheme.dark.chipTheme.selectedColor));
    },
  );
}
