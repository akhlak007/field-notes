import 'package:field_notes/core/config/app_config.dart';
import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/settings/settings_bloc.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

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
                  SectionCard(
                    title: 'Sync',
                    subtitle: 'Changes sync automatically when online. The first request after idle can take up to a minute while the server wakes.',
                    child: Text(
                      AppConfig.apiBaseUrl(),
                      style: Theme.of(context).textTheme.bodyMedium,
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
