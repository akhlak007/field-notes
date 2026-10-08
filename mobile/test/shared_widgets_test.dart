import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty state presents its message and action', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: EmptyState(
            message: 'No field notes yet.',
            actionLabel: 'Add note',
            onAction: () => acted = true,
          ),
        ),
      ),
    );

    expect(find.text('No field notes yet.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    await tester.tap(find.text('Add note'));
    expect(acted, isTrue);
  });

  testWidgets('sync error remains actionable with retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SyncStatusBar(
            state: const SyncState(
              online: true,
              pending: 2,
              error: 'Could not sync. Your changes are safe on this device.',
            ),
            onRetry: () => retries += 1,
          ),
        ),
      ),
    );

    expect(
      find.text('Could not sync. Your changes are safe on this device.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.textContaining('Could not sync'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
