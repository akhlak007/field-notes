import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/settings/settings_bloc.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthBloc>().state.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppHeader(title: 'Settings'),
                  SectionCard(
                    label: 'Account',
                    child: Text(
                      email,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Default note status',
                    subtitle: 'Used for new notes. Saved on this device only.',
                    child: BlocBuilder<SettingsBloc, SettingsState>(
                      builder: (context, state) {
                        return StatusPills(
                          value: state.defaultStatus,
                          onChanged: (value) {
                            if (value != null) {
                              context.read<SettingsBloc>().add(
                                DefaultStatusChanged(value),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  BlocBuilder<SyncBloc, SyncState>(
                    builder: (context, state) => SyncSettingsCard(
                      state: state,
                      onSyncRequested: () =>
                          context.read<SyncBloc>().add(const SyncRequested()),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: appDanger(context),
                        side: BorderSide(
                          color: appDanger(context).withValues(alpha: 0.65),
                        ),
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        minimumSize: const Size(48, 54),
                      ),
                      onPressed: () async {
                        final pending = context.read<SyncBloc>().state.pending;
                        if (pending > 0) {
                          final confirmed = await confirmDelete(
                            context,
                            title: 'Sign out with pending changes?',
                            message:
                                '$pending local change${pending == 1 ? '' : 's'} will stay safely on this device and sync when you sign back into this account.',
                            confirmLabel: 'Sign out',
                          );
                          if (!confirmed || !context.mounted) return;
                        }
                        context.read<AuthBloc>().add(const LogoutRequested());
                      },
                      child: const Text(
                        'Sign out',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncSettingsCard extends StatelessWidget {
  const SyncSettingsCard({
    super.key,
    required this.state,
    required this.onSyncRequested,
    this.now,
  });

  final SyncState state;
  final VoidCallback onSyncRequested;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final failed = state.error != null;
    return SectionCard(
      title: 'Sync',
      subtitle: "Changes sync automatically when you're online.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Last synced: ${_lastSyncedLabel(state.lastSyncedAt, now)}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (state.pending > 0) ...[
            const SizedBox(height: 6),
            Text(
              '${state.pending} change${state.pending == 1 ? '' : 's'} pending',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: appMuted(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 10),
            Text(
              'Sync failed. Your changes are safe.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: appDanger(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (state.syncing || failed) ...[
            const SizedBox(height: 8),
            Text(
              'The server may take up to a minute to respond after being idle.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: appMuted(context)),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: state.syncing ? null : onSyncRequested,
            icon: state.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: const Text('Sync now'),
          ),
          if (failed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onSyncRequested,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
        ],
      ),
    );
  }
}

String _lastSyncedLabel(DateTime? value, DateTime? currentTime) {
  if (value == null) return 'Never';
  final local = value.toLocal();
  final current = (currentTime ?? DateTime.now()).toLocal();
  final sameDay =
      local.year == current.year &&
      local.month == current.month &&
      local.day == current.day;
  if (sameDay) return 'Today, ${DateFormat('HH:mm').format(local)}';
  return DateFormat('d MMM yyyy, HH:mm').format(local);
}
