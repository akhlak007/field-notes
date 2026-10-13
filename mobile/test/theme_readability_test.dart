import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark semantic text colors meet normal-text contrast guidance', () {
    final theme = AppTheme.dark();
    final background = theme.scaffoldBackgroundColor;

    expect(_contrast(theme.colorScheme.onSurface, background), greaterThan(7));
    expect(
      _contrast(theme.colorScheme.onSurfaceVariant, background),
      greaterThan(4.5),
    );
    expect(_contrast(theme.colorScheme.primary, background), greaterThan(4.5));
    expect(
      _contrast(theme.colorScheme.error, theme.colorScheme.surface),
      greaterThan(4.5),
    );
  });

  testWidgets('shared navigation and filters use adaptive dark colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Column(
            children: [
              const AppHeader(title: 'Notes', subtitle: '2 notes · 2 open'),
              StatusPills(value: null, allowAll: true, onChanged: (_) {}),
              const Spacer(),
              HomeTabBar(index: 0, onChanged: _ignoreTab),
            ],
          ),
        ),
      ),
    );

    final context = tester.element(find.byType(StatusPills));
    expect(
      tester.widget<Text>(find.text('2 notes · 2 open')).style?.color,
      appMuted(context),
    );
    expect(
      tester.widget<Text>(find.text('Open')).style?.color,
      appInk(context),
    );
    expect(
      tester.widget<Text>(find.text('Notes').last).style?.color,
      appAccent(context),
    );
    expect(
      tester.widget<Text>(find.text('Customers')).style?.color,
      appMuted(context),
    );
  });

  testWidgets('light shared colors retain the reference palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Text(
            'Reference',
            style: TextStyle(
              color: appInk(context),
              backgroundColor: appMuted(context),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Reference'));
    expect(text.style?.color, AppColors.ink);
    expect(text.style?.backgroundColor, AppColors.muted);
  });
}

void _ignoreTab(int _) {}

double _contrast(Color foreground, Color background) {
  final light = foreground.computeLuminance();
  final dark = background.computeLuminance();
  final high = light > dark ? light : dark;
  final low = light > dark ? dark : light;
  return (high + 0.05) / (low + 0.05);
}
