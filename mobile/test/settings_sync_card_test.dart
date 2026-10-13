import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/settings/settings_page.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13, 21, 55);
  final lastSynced = DateTime(2026, 10, 13, 21, 49);

  testWidgets('idle state shows last sync and requests manual sync', (
    tester,
  ) async {
    var requests = 0;
    await _pumpCard(
      tester,
      SyncState(lastSyncedAt: lastSynced),
      now: now,
      onSyncRequested: () => requests += 1,
    );

    expect(
      find.text("Changes sync automatically when you're online."),
      findsOneWidget,
    );
    expect(find.text('Last synced: Today, 21:49'), findsOneWidget);
    expect(find.textContaining('changes pending'), findsNothing);
    expect(find.textContaining('onrender.com'), findsNothing);
    expect(find.textContaining('server may take'), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sync now'));
    expect(requests, 1);
  });

  testWidgets('genuinely empty cursor shows Never', (tester) async {
    await _pumpCard(tester, const SyncState(), now: now);

    expect(find.text('Last synced: Never'), findsOneWidget);
  });

  testWidgets('pending state shows the existing state count', (tester) async {
    await _pumpCard(
      tester,
      SyncState(pending: 3, lastSyncedAt: lastSynced),
      now: now,
    );

    expect(find.text('3 changes pending'), findsOneWidget);
  });

  testWidgets('syncing disables Sync now and shows progress and wake hint', (
    tester,
  ) async {
    var requests = 0;
    await _pumpCard(
      tester,
      SyncState(syncing: true, lastSyncedAt: lastSynced),
      now: now,
      onSyncRequested: () => requests += 1,
    );

    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Sync now'),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.text(
        'The server may take up to a minute to respond after being idle.',
      ),
      findsOneWidget,
    );
    expect(requests, 0);
  });

  testWidgets('failed state is short, safe, and retryable', (tester) async {
    var requests = 0;
    await _pumpCard(
      tester,
      SyncState(
        pending: 2,
        error: 'https://internal.example/raw-stack-trace',
        lastSyncedAt: lastSynced,
      ),
      now: now,
      onSyncRequested: () => requests += 1,
    );

    expect(find.text("Sync failed. Your changes are safe."), findsOneWidget);
    expect(find.textContaining('internal.example'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.text(
        'The server may take up to a minute to respond after being idle.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Retry'));
    expect(requests, 1);
  });

  testWidgets('fits 360px width with large system text', (tester) async {
    await _pumpCard(
      tester,
      SyncState(syncing: true, pending: 12, lastSyncedAt: lastSynced),
      now: now,
      size: const Size(360, 800),
      textScaler: const TextScaler.linear(1.6),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('12 changes pending'), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  SyncState state, {
  required DateTime now,
  VoidCallback? onSyncRequested,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(size: size, textScaler: textScaler),
        child: Scaffold(
          body: SingleChildScrollView(
            child: SyncSettingsCard(
              state: state,
              now: now,
              onSyncRequested: onSyncRequested ?? () {},
            ),
          ),
        ),
      ),
    ),
  );
}
